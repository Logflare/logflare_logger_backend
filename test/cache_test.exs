defmodule LogflareLogger.CacheTest do
  use ExUnit.Case
  alias LogflareLogger.Cache
  @test_batch_key :test_batch

  test "cache puts events, gets events and resets batch" do
    ev1 = %{metadata: %{}, message: "log1"}
    ev2 = %{metadata: %{}, message: "log2"}

    assert Cache.add_event_to_batch(ev1, @test_batch_key) === [ev1]

    assert Cache.add_event_to_batch(ev2, @test_batch_key) === [ev2, ev1]

    _ = Cache.reset_batch(@test_batch_key)

    assert Cache.get_batch(@test_batch_key) === []
  end
end
