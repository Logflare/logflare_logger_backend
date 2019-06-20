defmodule LogflareLogger.LogParamsTest do
  @moduledoc false
  use ExUnit.Case
  alias LogflareLogger.{LogParams}
  require Logger
  use Placebo

  describe "LogParams" do
    test "converts tuples to lists" do
      x = %{tuples: {1, "tuple1", {2, "tuple2", {3, "tuple3"}}}}
      user_context = build_user_context(x)
      assert user_context === %{"tuples" => [1, "tuple1", [2, "tuple2", [3, "tuple3"]]]}
    end

    test "converts structs to maps" do
      x = %Time{hour: 0, minute: 0, second: 0}
      user_context = build_user_context(%{struct: x})

      assert user_context === %{
               "struct" => %{
                 "calendar" => "Elixir.Calendar.ISO",
                 "hour" => 0,
                 "microsecond" => [0, 0],
                 "minute" => 0,
                 "second" => 0
               }
             }
    end

    test "converts charlists to strings" do
      x = 'just a simple charlist'
      user_context = build_user_context(%{charlist: %{x => [x, %{x => {x, x}}]}})

      x = to_string(x)
      assert user_context === %{"charlist" => %{x => [x, %{x => [x, x]}]}}
    end
  end

  def build_user_context(metadata) do
    timestamp = Timex.now() |> Timex.to_erl()

    LogParams.encode(timestamp, :info, "test message", metadata)
    |> Map.get("metadata")
    |> Map.get("context")
    |> Map.get("user")
  end
end
