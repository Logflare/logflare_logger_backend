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
                   "adapter" => ["Elixir.Plug.Cowboy.Conn", "{\"peer\":[[127,0,0,1],60164]}"]
                 }
               }
             }

      # No changes applied on lists with same types
      body = %{"metadata" => %{"conn" => %{"adapter" => ["Elixir.Plug.Cowboy.Conn", "normal"]}}}
      changeset = PendingLoggerEvent.changeset(%PendingLoggerEvent{}, %{body: body})

      assert changeset.changes.body == body

      # No changes applied on lists with same types
      body = %{"metadata" => %{"conn" => %{"adapter" => %{"a" => "b", "c" => "d"}}}}
      changeset = PendingLoggerEvent.changeset(%PendingLoggerEvent{}, %{body: body})

      assert changeset.changes.body == body
    end

    test "unencodable types are converted via inspect fallback" do
      port = Port.open({:spawn, "cat"}, [:binary])
      Port.close(port)

      unencodable_values = [
        {port, "#Port<"},
        {make_ref(), "#Reference<"},
        {self(), "#PID<"}
      ]

      for {value, expected_prefix} <- unencodable_values do
        body = %{"data" => ["string", value], "value" => value, "int" => 123.1}
        changeset = PendingLoggerEvent.changeset(%PendingLoggerEvent{}, %{body: body})

        [first, second] = changeset.changes.body["data"]

        assert first == "string"
        assert String.starts_with?(second, expected_prefix)
        assert changeset.changes.body["value"] =~ expected_prefix
        assert changeset.changes.body["int"] == 123.1
      end
    end

    test "complex nested structures are stringified to avoid BigQuery errors" do
      body = %{
        "req_headers" => [["accept", "*/*"], ["content-type", "json"]],
        "response" => {:ok, "success"},
        "results" => [{:ok, "first"}, {:error, "second"}],
        "timestamps" => [[~D[2024-01-01], ~T[12:00:00]]],
        "three_levels" => [[["deep"]]],
        "four_levels" => [[[["nested"]]], [nil]]
      }

      for {k, v} <- body do
        changeset =
          PendingLoggerEvent.changeset(%PendingLoggerEvent{}, %{body: Map.new([{k, v}])})

        result = changeset.changes.body
        assert Map.get(result, k) |> is_binary(), "should be stringified: #{k}"
      end
    end
  end
end
