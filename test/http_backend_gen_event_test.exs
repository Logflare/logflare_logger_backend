defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias LogflareLogger.{HttpBackend, Formatter, BatchCache}
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

  setup_all do
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

      Enum.reduce(
        1..10,
        state,
        fn i, acc ->
          msg = {:info, nil, {Logger, "log message", ts(i), []}}
          {:ok, state} = HttpBackend.handle_event(msg, acc)
          state
        end
      )

      Process.sleep(200)

      assert_called(
        LogflareApiClient.post_logs(
          any(),
          is(fn batch ->
            assert length(batch) == 10
          end),
          any()
        )
      )
    end
  end

  describe "HttpBackend.handle_event/2 with deprecated `metadata` keyword list config" do
    test "the emitted deprecation warning is itself re-processed as a log event and re-emits the warning, risking an infinite loop" do
      allow(LogflareApiClient.post_logs(any(), any(), any()), return: {:ok, %Tesla.Env{}})

      {:ok, state} = init_with_default(metadata: [:some_key])

      info_msg = {:info, nil, {Logger, "log message", ts(0), []}}

      log =
        capture_log(fn ->
          {:ok, _state} = HttpBackend.handle_event(info_msg, state)
        end)

      assert log =~ "deprecated"

      # When this backend is attached to Logger (as it is in real usage), the
      # deprecation warning logged above is itself dispatched back to
      # handle_event/2 as a new log event. Since format_event/5 only looks at
      # the backend's config (still the deprecated keyword list) and not at
      # the contents of the message, it re-emits the same warning here too -
      # this is what causes the infinite loop.
      warning_msg =
        {:warning, nil,
         {Logger,
          "Your logflare_logger_backend configuration key `metadata` is deprecated. Looks like you're using a list of keywords. Please use `metadata: :all` or `metadata: [drop: [:keys, :to, :drop]]`",
          ts(1), []}}

      log2 =
        capture_log(fn ->
          {:ok, _state} = HttpBackend.handle_event(warning_msg, state)
        end)

      assert log2 =~ "deprecated"
    end
  end

  describe "HttpBackend.handle_info/2" do
    test "flushes after :flush msg" do
      {:ok, state} = init_with_default()
      {:ok, _state} = HttpBackend.handle_info(:flush, state)
      assert_receive :flush, @default_config[:flush_interval] + 10
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
