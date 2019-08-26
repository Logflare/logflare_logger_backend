defmodule LogflareLogger.ExceptionLoggingTest do
  @moduledoc false
  use ExUnit.Case
  alias LogflareLogger.{ApiClient, TestUtils, HttpBackend}
  alias Jason, as: JSON
  require Logger
  use Placebo

  @path ApiClient.api_path()

  @logger_backend HttpBackend
  @api_key "l3kh47jsakf2370dasg"
  @source "source2354551"

  setup do
    Application.put_env(:logflare_logger_backend, :url, "http://127.0.0.1:4000")
    Application.put_env(:logflare_logger_backend, :api_key, @api_key)
    Application.put_env(:logflare_logger_backend, :source_id, @source)
    Application.put_env(:logflare_logger_backend, :level, :info)
    Application.put_env(:logflare_logger_backend, :flush_interval, 500)
    Application.put_env(:logflare_logger_backend, :max_batch_size, 5)

    Logger.add_backend(@logger_backend)

    :ok
  end

  test "logger backends sends a formatted log event after an exception" do
    allow ApiClient.post_logs(any(), any(), any()), return: {:ok, %Tesla.Env{status: 200}}

    spawn(fn -> 3.14 / 0 end)
    spawn(fn -> 3.14 / 0 end)
    spawn(fn -> 3.14 / 0 end)
    spawn(fn -> Enum.find(nil, & &1) end)

    Process.sleep(1_000)

    assert_called(
      ApiClient.post_logs(
        any(),
        is(fn xs ->
          [
            %{
              "message" => _,
              "metadata" => %{
                "level" => "error",
                "context" => %{"pid" => _},
                "stacktrace" => [_ | _]
              },
              "timestamp" => _
            }
            | _
          ] = xs

          true
        end),
        any()
      )
    )
  end
end
