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

  describe "HttpBackend.init/2" do
    test "succeeds with correct config" do
      {:ok, state} = HttpBackend.init(HttpBackend, @default_config)
      assert state.level == :info
      assert_receive :flush, @default_config[:flush_interval] + 10
    end
  end
end
