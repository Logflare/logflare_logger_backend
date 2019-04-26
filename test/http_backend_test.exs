defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case, async: true
  require Logger

  @host "127.0.0.1"

  @logger_backend {LogflareLogger.Backend, :test}
  Logger.add_backend(@logger_backend)

  setup do
    bypass = Bypass.open()

    :ok =
      Logger.configure_backend(
        @logger_backend,
        host: @host,
        port: bypass.port,
        level: :info,
        type: "testing",
        metadata: []
      )

    {:ok, bypass: bypass}
  end

  test "logger backend sends a POST request", %{bypass: bypass} do
    log_msg = "Incoming log from test"

    Bypass.expect_once(bypass, "POST", "/api/v0/elixir-logger", fn conn ->
      {:ok, ^log_msg, conn} = Plug.Conn.read_body(conn)
      Plug.Conn.resp(conn, 200, "")
    end)

    :ok = Logger.info(log_msg)
    Process.sleep(100)
  end

  test "doesn't POST log events with a lower level", %{bypass: bypass} do
    log_msg = "Incoming log from test"

    :ok = Logger.info(log_msg)
    Process.sleep(100)
  end
end
