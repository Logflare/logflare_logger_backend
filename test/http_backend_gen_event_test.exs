defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case
  alias LogflareLogger.{HttpBackend, Formatter, BatchCache, Repo, PendingLoggerEvent}
  use Placebo

  @default_config [
    format: {Formatter, :format},
    min_level: :info,
    flush_interval: 300,
    url: "http://localhost:4000/logs/elixir/logger",
    source_id: "source",
    api_key: "api_key",
    batch_max_size: 10,
    metadata: []
  ]

  setup do
    on_exit(fn ->
      BatchCache.clear()
      Logger.flush()
    end)

    :ok
  end

  describe "HttpBackend.init/2" do
    test "succeeds with correct config" do
      {:ok, state} = init_with_default()
      assert state.level == :info
      assert_receive :flush, @default_config[:flush_interval] + 10
    end
  end

  describe "HttpBackend.handle_event/2" do
    test "flushes after :flush msg" do
      {:ok, state} = init_with_default()
      {:ok, _state} = HttpBackend.handle_event(:flush, state)
      assert_receive :flush, @default_config[:flush_interval] + 10
    end

    test "new log message gets flushed within the interval" do
      {:ok, state} = init_with_default()
      msg = {:info, nil, {Logger, "log message", ts(0), []}}
      {:ok, _state} = HttpBackend.handle_event(msg, state)
      assert_receive :flush, @default_config[:flush_interval] + 10
    end

    test "flushes after batch reaches max_batch_size" do
      allow(LogflareApiClient.post_logs(any(), any(), any()), return: {:ok, %Tesla.Env{}})

      {:ok, state} = init_with_default(flush_interval: 60_000)

      generate_logs(state, @default_config[:batch_max_size])

      Process.sleep(200)

      assert_called(
        LogflareApiClient.post_logs(
          any(),
          is(fn batch ->
            assert length(batch) == @default_config[:batch_max_size]
          end),
          any()
        ),
        once()
      )
    end

    test "flush not called if log events are in flight" do
      allow(LogflareApiClient.post_logs(any(), any(), any()), return: {:ok, %Tesla.Env{}})

      {:ok, state} = init_with_default(flush_interval: 60_000)

      generate_logs(state, @default_config[:batch_max_size] - 1)

      for e <- BatchCache.pending_events_not_in_flight() do
        e
        |> PendingLoggerEvent.changeset(%{api_request_started_at: System.monotonic_time()})
        |> Repo.update()
      end

      generate_logs(state, @default_config[:batch_max_size])

      refute_called(LogflareApiClient.post_logs(any(), any(), any()))
    end
  end

  describe "HttpBackend.handle_info/2" do
    test "flushes after :flush msg" do
      {:ok, state} = init_with_default()
      {:ok, _state} = HttpBackend.handle_info(:flush, state)
      assert_receive :flush, @default_config[:flush_interval] + 10
    end
  end

  defp generate_logs(state, count) do
    for i <- 1..count do
      msg = {:info, nil, {Logger, "log message", ts(i), []}}
      {:ok, _state} = HttpBackend.handle_event(msg, state)
    end
  end

  defp init_with_default() do
    HttpBackend.init(HttpBackend, @default_config)
  end

  defp init_with_default(kw) do
    config = Keyword.merge(@default_config, kw)
    HttpBackend.init(HttpBackend, config)
  end

  defp ts(sec) do
    {{2019, 1, 1}, {0, 0, sec, 0}}
  end
end
