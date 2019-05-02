defmodule LogflareLoggerTest do
  use ExUnit.Case
  import LogflareLogger
  doctest LogflareLogger

  test "gets, sets and unsets one context key" do
    assert context() == %{}

    assert set_context(advanced_logging: true) == %{advanced_logging: true}
    assert set_context(advanced_logging: false) == %{advanced_logging: false}
    assert set_context(simple_logging: true) == %{simple_logging: true, advanced_logging: false}
    assert context() == %{simple_logging: true, advanced_logging: false}

    :ok = unset_context(:simple_logging)
    :ok = unset_context(:advanced_logging)
    assert context() == %{}
  end

  test "gets, sets and unsets multiple context keys" do
    assert context() == %{}

    assert set_context(key1: 1, key2: 2) == %{key1: 1, key2: 2}
    assert set_context(key2: 3, key4: 4) == %{key1: 1, key2: 3, key4: 4}
    assert context() == %{key1: 1, key2: 3, key4: 4}

    :ok = unset_context()
    assert context() == %{}
  end
    assert context() == %{}
  end
end
