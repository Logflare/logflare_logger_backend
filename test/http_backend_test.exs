defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case, async: true

  @host "127.0.0.1"
  @port 42_314

  @logger_backend {LogflareLoggerBackend, :test}
  Logger.add_backend(@logger_backend)

  setup do
    Logger.configure_backend(
      @backend,
      host: @host,
      port: @port,
      level: :info,
      type: "testing",
      metadata: []
    )

    bypass = Bypass.open(@port)

    {:ok, bypass: bypass}
  end

  test "backend sends a POST request", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/api/v0/elixir-logger", fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Logger.info("Incoming log from test")
  end
end
