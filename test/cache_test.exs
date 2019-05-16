defmodule LogflareLogger.BatchCacheTest do
  @moduledoc false
  use ExUnit.Case
  alias LogflareLogger.{BatchCache, ApiClient}
  @test_batch_key :test_batch
  @backend_config %{
    api_client: ApiClient.new(%{url: "http://localhost:4000", api_key: ""}),
    source_id: "source-id",
    batch_max_size: 10
  }

  test "cache puts events, gets events and resets batch" do
    ev1 = %{metadata: %{}, message: "log1"}
    ev2 = %{metadata: %{}, message: "log2"}

    assert BatchCache.put(ev1, @backend_config) === %{count: 1, events: [ev1]}

    assert BatchCache.put(ev2, @backend_config) === %{count: 2, events: [ev2, ev1]}

    BatchCache.put_initial()

    assert BatchCache.get!() === %{count: 0, events: []}
  end
end
