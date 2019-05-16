defmodule LogflareLoggerTest do
  @moduledoc false
  use ExUnit.Case
  import LogflareLogger
  doctest LogflareLogger

  setup do
    on_exit(&LogflareLogger.delete_context/0)
  end
  
  test "gets, sets and unsets one context key" do
    assert get_context() == %{}

    assert merge_context(advanced_logging: true) == %{advanced_logging: true}
    assert merge_context(advanced_logging: false) == %{advanced_logging: false}
    assert merge_context(simple_logging: true) == %{simple_logging: true, advanced_logging: false}
    assert get_context() == %{simple_logging: true, advanced_logging: false}

    :ok = delete_context(:simple_logging)
    :ok = delete_context(:advanced_logging)
    assert get_context() == %{}
  end

  test "gets, sets and unsets multiple context keys" do
    assert get_context() == %{}

    assert merge_context(key1: 1, key2: 2) == %{key1: 1, key2: 2}
    assert merge_context(key2: 3, key4: 4) == %{key1: 1, key2: 3, key4: 4}
    assert get_context() == %{key1: 1, key2: 3, key4: 4}

    :ok = delete_context()
    assert get_context() == %{}
  end

  test "set context raises for invalid values" do
    assert_raise FunctionClauseError, fn ->
      merge_context(nil)
    end

    assert_raise FunctionClauseError, fn ->
      merge_context(false)
    end

    assert_raise FunctionClauseError, fn ->
      merge_context(1_000)
    end
  end
end
