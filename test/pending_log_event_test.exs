defmodule LogflareLogger.PendingLoggerEventTest do
  use ExUnit.Case
  alias LogflareLogger.PendingLoggerEvent

  describe "changeset/2" do
    test "list with different types handled in metadata" do
      # changes applied to nested map
      body = %{
        "metadata" => %{
          "conn" => %{
            "adapter" => [
              "Elixir.Plug.Cowboy.Conn",
              %{"peer" => [[127, 0, 0, 1], 60164]}
            ]
          }
        }
      }

      changeset = PendingLoggerEvent.changeset(%PendingLoggerEvent{}, %{body: body})

      assert changeset.changes.body
             |> get_in(["metadata", "conn", "adapter"])
             |> Enum.all?(fn x -> is_binary(x) end)

      assert changeset.changes.body == %{
               "metadata" => %{
                 "conn" => %{
                   "adapter" => [
                     "Elixir.Plug.Cowboy.Conn",
                     "%{\"peer\" => [[127, 0, 0, 1], 60164]}"
                   ]
                 }
               }
             }

      # No changes applied on lists with same types
      body = %{"metadata" => %{"conn" => %{"adapter" => ["Elixir.Plug.Cowboy.Conn", "normal"]}}}
      changeset = PendingLoggerEvent.changeset(%PendingLoggerEvent{}, %{body: body})

      assert changeset.changes.body == body
    end
  end
end
