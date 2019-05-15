defmodule LogflareLogger.ExceptionLoggingTest do
  use ExUnit.Case
  alias LogflareLogger.{HttpBackend, Formatter}
  alias LogflareLogger.{ApiClient, TestUtils}
  alias Jason, as: JSON
  require Logger

  @path ApiClient.api_path()

  @logger_backend HttpBackend
  @api_key "l3kh47jsakf2370dasg"
  @source "source2354551"

  setup do
    port = 44444
    bypass = Bypass.open(port: port)
    Application.put_env(:logflare_logger_backend, :url, "http://127.0.0.1:#{port}")
    Application.put_env(:logflare_logger_backend, :api_key, @api_key)
    Application.put_env(:logflare_logger_backend, :source_id, @source)
    Application.put_env(:logflare_logger_backend, :level, :info)
    Application.put_env(:logflare_logger_backend, :flush_interval, 500)
    Application.put_env(:logflare_logger_backend, :max_batch_size, 100)

    Logger.add_backend(@logger_backend)

    {:ok, bypass: bypass, config: %{}}
  end

  test "logger backends sends a formatted log event after an exception", %{
    bypass: bypass,
    config: config
  } do
    Bypass.expect(bypass, "POST", @path, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert {"x-api-key", @api_key} in conn.req_headers

      body = TestUtils.decode_logger_body(body)

      assert %{
               "batch" => [
                 %{
                   "level" => level,
                   "message" => message,
                   "metadata" => %{
                     "context" => %{
                       "pid" => _
                     },
                     "stacktrace" => stacktrace
                   },
                   "timestamp" => _
                 }
                 | _
               ],
               "source" => @source
             } = body

      assert is_list(stacktrace)
      Plug.Conn.resp(conn, 200, "")
    end)

    spawn(fn -> 3.14 / 0 end)
    Process.sleep(1_000)
  end
end
