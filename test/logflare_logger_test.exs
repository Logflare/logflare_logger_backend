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
    assert context() == %{}
  end
end
