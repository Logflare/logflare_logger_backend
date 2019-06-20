defmodule LogflareLogger.LogParamsTest do
  @moduledoc false
  use ExUnit.Case
  alias LogflareLogger.{LogParams}
  require Logger
  use Placebo

  describe "LogParams" do
    test "converts tuples to lists" do
      x = %{tuples: {1, "tuple1", {2, "tuple2", {3, "tuple3"}}}}
      assert build_user_context(x) === %{"tuples" => [1, "tuple1", [2, "tuple2", [3, "tuple3"]]]}
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
