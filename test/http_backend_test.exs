defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case, async: false
  alias LogflareLogger.{HttpBackend, Formatter}
  alias LogflareLogger.ApiClient
  alias Jason, as: JSON
  require Logger

  @port 4444
  @path ApiClient.api_path()


  @logger_backend HttpBackend

  setup do
    bypass = Bypass.open(port: @port)
    Application.put_env(:logflare_logger, :url, "http://127.0.0.1:#{@port}")
    Application.put_env(:logflare_logger, :level, :info)
    Application.put_env(:logflare_logger, :flush_interval, 500)
    Application.put_env(:logflare_logger, :max_batch_size, 100)

    Logger.add_backend(@logger_backend)

    {:ok, bypass: bypass, config: %{}}
  end

  test "logger backend sends a POST request", %{bypass: bypass, config: config} do
    log_msg = "Incoming log from test"

    Bypass.expect(bypass, "POST", @path, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      body = JSON.decode!(body)

      assert %{
               "batch" => [
                 %{
                   "level" => level,
                   "message" => "Incoming log from test " <> _,
                   "metadata" => %{},
                   "timestamp" => _
                 }
                 | _
               ]
             } = body

      assert length(body["batch"]) == 10
      assert level in ["info", "error"]

      Plug.Conn.resp(conn, 200, "")
    end)

    for n <- 1..10, do: Logger.info(log_msg <> " ##{n}")

    Process.sleep(1_000)

    for n <- 1..10, do: Logger.error(log_msg <> " ##{20 + n}")

    Process.sleep(1_000)

    for n <- 1..10, do: Logger.debug(log_msg <> " ##{30 + n}")

    Process.sleep(1_000)
  end

  test "doesn't POST log events with a lower level", %{bypass: _bypass, config: config} do
    log_msg = "Incoming log from test"

    :ok = Logger.debug(log_msg)
  end

  @msg "Incoming log from test with all metadata"
  test "correctly handles metadata keys", %{bypass: bypass, config: config} do
    :ok = Logger.configure_backend(@logger_backend, metadata: :all)

    Bypass.expect_once(bypass, "POST", @path, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      body = JSON.decode!(body)

      assert %{
               "batch" => [
                 %{
                   "level" => "info",
                   "message" => @msg,
                   "metadata" => %{
                     "pid" => pidbinary,
                     "module" => _,
                     "file" => _,
                     "line" => _,
                     "function" => _
                   },
                   "timestamp" => _
                 }
                 | _
               ]
             } = body

      assert is_binary(pidbinary)

      assert length(body["batch"]) == 45

      Plug.Conn.resp(conn, 200, "")
    end)

    log_msg = @msg

    for n <- 1..45, do: Logger.info(log_msg)

    Process.sleep(1_000)
  end
end
