defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case
  alias LogflareLogger.{HttpBackend, Formatter}

  @default_config [
    format: {Formatter, :format},
    min_level: :info,
    flush_interval: 100,
    url: "http://localhost:4000/logs/elixir/logger",
    source: "source",
    api_key: "api_key",
    max_batch_size: 10,
    metadata: []
  ]

  setup_all do
    Mox.defmock(ApiClientMock, for: ApiClient)
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

    test "flush after max batch size" do
      {:ok, state} = init_with_default()
      msg = {:info, nil, {Logger, "log message", ts(1), []}}

      assert_receive :flush, @default_config[:flush_interval] + 10

      Enum.reduce(2..10, state, fn i, acc ->
        msg = {:info, nil, {Logger, "log message", ts(i), []}}
        {:ok, state} = HttpBackend.handle_event(msg, acc)
        state
      end)
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

  defp ts(sec) do
    {{2019, 1, 1}, {0, 0, sec, 0}}
  end
end
