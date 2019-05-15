defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case
  alias LogflareLogger.{HttpBackend, Formatter, BatchCache, ApiClient}
  import Mox

  @default_config [
    format: {Formatter, :format},
    min_level: :info,
    flush_interval: 300,
    url: "http://localhost:4000/logs/elixir/logger",
    source: "source",
    api_key: "api_key",
    max_batch_size: 10,
    metadata: []
  ]

  setup_all do
    Application.put_env(:logflare_logger, :test_env, api_client: ApiClientMock)
    Mox.defmock(ApiClientMock, for: ApiClient)
    on_exit(&BatchCache.put_initial/1)
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
      {:ok, state} = HttpBackend.handle_event(:flush, state)
      assert_receive :flush, @default_config[:flush_interval] + 10
    end

    test "new log message gets flushed within the interval" do
      {:ok, state} = init_with_default()
      msg = {:info, nil, {Logger, "log message", ts(0), []}}
      {:ok, state} = HttpBackend.handle_event(msg, state)
      assert_receive :flush, @default_config[:flush_interval] + 10
    end

    test "flushes after batch reaches max_batch_size" do
      expect(
        ApiClientMock,
        :post_logs,
        fn client, batch, source ->
          assert length(batch) == 10
          {:ok, %{}}
        end
      )
      {:ok, state} = init_with_default(flush_interval: 60_000)
      msg = {:info, nil, {Logger, "log message", ts(1), []}}

      Enum.reduce(
        2..10,
        state,
        fn i, acc ->
          msg = {:info, nil, {Logger, "log message", ts(i), []}}
          {:ok, state} = HttpBackend.handle_event(msg, acc)
          state
        end
      )
    end
  end

  describe "HttpBackend.handle_info/2" do
    test "flushes after :flush msg" do
      {:ok, state} = init_with_default()
      {:ok, state} = HttpBackend.handle_info(:flush, state)
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
