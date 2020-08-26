defmodule LogflareLogger.LogParamsTest do
  @moduledoc false
  use ExUnit.Case
  alias LogflareLogger.{LogParams}
  require Logger
  use Placebo

  describe "LogParams conversion" do
    test "tuples to lists" do
      x = %{tuples: {1, "tuple1", {2, "tuple2", {3, "tuple3"}}}}
      user_context = build_user_context(x)

      assert user_context === %{"tuples" => [1, "tuple1", [2, "tuple2", [3, "tuple3"]]]}
    end

    test "structs to maps" do
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

    test "charlists to strings" do
      x = 'just a simple charlist'
      user_context = build_user_context(%{charlist: %{x => [x, %{x => {x, x}}]}})

      x = to_string(x)
      assert user_context === %{"charlist" => %{x => [x, %{x => [x, x]}]}}
    end

    test "keywords to maps" do
      x = [a: 2, b: [a: 6]]
      user_context = build_user_context(%{keyword: %{1 => [x, %{two: {x, x}}]}})

      x = %{"a" => 2, "b" => %{"a" => 6}}
      assert user_context === %{"keyword" => %{1 => [x, %{"two" => [x, x]}]}}
    end

    test "observer_backend.sys_info()" do
      user_context = build_user_context(observer_sys_info: :observer_backend.sys_info())

      assert ["instance", 0, %{"mbcs" => _, "sbcs" => _}] =
               hd(user_context["observer_sys_info"]["alloc_info"]["binary_alloc"])
    end

    test "pid to string" do
      user_context = build_user_context(user_pid: self())

      %{"user_pid" => pid} = user_context
      assert is_binary(pid)
    end

    test "function to string" do
      user_context =
        build_user_context(user_field: %{error_response: [:invalid, &String.to_atom/1]})

      %{"user_field" => %{"error_response" => [invalid, fun]}} = user_context
      assert fun == "&String.to_atom/1"
      assert invalid == "invalid"
    end

    test "NaiveDateTime and DateTime to String.Chars protocol" do
      {:ok, ndt} = NaiveDateTime.new(1337, 4, 19, 0, 0, 0)

      user_context =
        build_user_context(
          datetimes: %{
            ndt: ndt,
            dt: DateTime.from_naive!(ndt, "Etc/UTC")
          }
        )

      assert user_context == %{
               "datetimes" => %{"dt" => "1337-04-19 00:00:00Z", "ndt" => "1337-04-19 00:00:00"}
             }
    end
  end

  describe "LogParams doesn't convert" do
    test "booleans" do
      x = %{true: {true, [true]}}
      user_context = build_user_context(x)

      assert user_context === %{true: [true, [true]]}
    end
  end

  describe "LogParams" do
    test "correctly encodes timestamp datetimes without millis" do
      {date, time} = :calendar.local_time()
      {hour, minute, second} = time

      utc = %{NaiveDateTime.utc_now() | microsecond: {0, 6}}

      utcstring = NaiveDateTime.to_iso8601(utc, :extended) <> "Z"

      assert utcstring == LogParams.encode_timestamp({date, time})
    end

    test "correctly encdoes timestamp datetimes with millis" do
      {date, time} = :calendar.local_time()
      {hour, minute, second} = time

      utc = %{NaiveDateTime.utc_now() | microsecond: {314_159, 6}}
      utcstring = NaiveDateTime.to_iso8601(utc, :extended) <> "Z"
      {millis, _} = utc.microsecond

      assert utcstring ==
               LogParams.encode_timestamp({date, {hour, minute, second, millis / 1000}})
    end

    test "handles report_cb" do
      metadata = [report: %{}, report_cb: fn x -> x end, level: :info]
      timestamp = :calendar.universal_time()
      lp = LogParams.encode(timestamp, :info, "test message", metadata)

      assert %{
               "message" => "test message",
               "metadata" => %{
                 "context" => %{"vm" => %{"node" => "nonode@nohost"}},
                 "level" => "info",
                 "report" => %{}
               },
               "timestamp" => _
             } = lp
    end

    test "puts level field in metadata" do
      timestamp = :calendar.universal_time()
      lp = LogParams.encode(timestamp, :info, "test message", level: "nope")

      assert lp["metadata"]["level"] == "info"
    end

    test "vm and node data is present in system context" do
      timestamp = :calendar.universal_time()
      lp = LogParams.encode(timestamp, :info, "test message", level: "nope")

      assert lp["metadata"]["context"]["vm"]["node"] == "#{Node.self()}"
    end
  end

  defp build_user_context(metadata) do
    timestamp = :calendar.universal_time()

    LogParams.encode(timestamp, :info, "test message", metadata)
    |> Map.get("metadata")
    |> Map.drop(["context", "level"])
  end
end
