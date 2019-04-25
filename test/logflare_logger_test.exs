defmodule LogflareLoggerTest do
  use ExUnit.Case
  doctest LogflareLogger

  test "greets the world" do
    assert LogflareLogger.hello() == :world
  end
end
