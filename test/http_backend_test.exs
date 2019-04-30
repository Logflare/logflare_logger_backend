defmodule LogflareLogger.HttpBackendTest do
  use ExUnit.Case, async: false
  alias LogflareLogger.{HttpBackend, Formatter}
  alias Jason, as: JSON
  require Logger

  @host "127.0.0.1"
  @port 4444

  @default_config [
    host: @host,
    port: @port,
    format: {Formatter, :format},
    level: :info,
    flush_interval: 500,
    max_batch_size: 100,
    type: "testing",
    metadata: []
  ]

  @logger_backend HttpBackend
  Logger.add_backend(@logger_backend)

  setup do
    bypass = Bypass.open(port: @port)

    :ok = Logger.configure_backend(@logger_backend, @default_config)

    {:ok, bypass: bypass, config: %{}}
  end

  test "logger backend sends a POST request", %{bypass: bypass, config: config} do
    log_msg = "Incoming log from test"

    Bypass.expect(bypass, "POST", "/api/v0/elixir-logger", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      body = JSON.decode!(body)

      assert [
               %{
                 "level" => "info",
                 "message" => "Incoming log from test " <> _,
                 "metadata" => %{},
                 "timestamp" => _
               }
               | _
             ] = body

      assert length(body) == 10

      Plug.Conn.resp(conn, 200, "")
    end)

    for n <- 1..10, do: Logger.info(log_msg <> " ##{n}")

    Process.sleep(1_000)

    for n <- 1..10, do: Logger.info(log_msg <> " ##{10 + n}")

    Process.sleep(1_000)
  end

  test "doesn't POST log events with a lower level", %{bypass: _bypass, config: config} do
    log_msg = "Incoming log from test"

    :ok = Logger.debug(log_msg)
  end

  @msg "Incoming log from test with all metadata"
  test "correctly handles metadata keys", %{bypass: bypass, config: config} do

    :ok = Logger.configure_backend(@logger_backend, metadata: :all)

    Bypass.expect_once(bypass, "POST", "/api/v0/elixir-logger", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      body = JSON.decode!(body)
      assert [
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
             ] = body

      assert is_binary(pidbinary)

      assert length(body) == 45

      Plug.Conn.resp(conn, 200, "")
    end)

    log_msg = @msg

    for n <- 1..45, do: Logger.info(log_msg)

    Process.sleep(1_000)
  end
end
