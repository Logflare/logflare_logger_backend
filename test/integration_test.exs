defmodule LogflareLogger.IntegrationTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias LogflareLogger.{HttpBackend, TestUtils}
  require Logger

  @path LogflareApiClient.api_path()

  @logger_backend HttpBackend
  @api_key "l3kh47jsakf2370dasg"
  @source "source2354551"

  setup do
    bypass = Bypass.open()

    url = Application.get_env(:logflare_logger_backend, :url)
    api_key = Application.get_env(:logflare_logger_backend, :api_key)
    source_id = Application.get_env(:logflare_logger_backend, :source_id)
    level = Application.get_env(:logflare_logger_backend, :level)
    flush_interval = Application.get_env(:logflare_logger_backend, :flush_interval)
    max_batch_size = Application.get_env(:logflare_logger_backend, :max_batch_size)

    Application.put_env(:logflare_logger_backend, :url, "http://127.0.0.1:#{bypass.port}")
    Application.put_env(:logflare_logger_backend, :api_key, @api_key)
    Application.put_env(:logflare_logger_backend, :source_id, @source)
    Application.put_env(:logflare_logger_backend, :level, :info)
    Application.put_env(:logflare_logger_backend, :flush_interval, 900)
    Application.put_env(:logflare_logger_backend, :max_batch_size, 100)

    Logger.add_backend(@logger_backend)

    on_exit(fn ->
      LogflareLogger.context(test_context: nil)
      Logger.remove_backend(@logger_backend, flush: true)
      Application.put_env(:logflare_logger_backend, :url, url)
      Application.put_env(:logflare_logger_backend, :api_key, api_key)
      Application.put_env(:logflare_logger_backend, :source_id, source_id)
      Application.put_env(:logflare_logger_backend, :level, level)
      Application.put_env(:logflare_logger_backend, :flush_interval, flush_interval)
      Application.put_env(:logflare_logger_backend, :max_batch_size, max_batch_size)
    end)

    {:ok, bypass: bypass}
  end

  test "logger backend sends a POST request", %{bypass: bypass} do
    :ok = Logger.configure_backend(@logger_backend, metadata: [])
    log_msg = "Incoming log from test"
    LogflareLogger.context(test_context: %{some_metric: 1337})

    Bypass.expect(bypass, "POST", @path, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert {"x-api-key", @api_key} in conn.req_headers

      body = TestUtils.decode_logger_body(body)

      assert %{
               "batch" => [
                 %{
                   "message" => "Incoming log from test " <> _,
                   "metadata" => %{
                     "level" => level,
                     "context" => %{"pid" => _},
                     "test_context" => %{"some_metric" => 1337}
                   },
                   "timestamp" => _
                 }
                 | _
               ],
               "source" => @source
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

  test "doesn't POST log events with a lower level", %{bypass: _bypass} do
    log_msg = "Incoming log from test"

    :ok = Logger.debug(log_msg)
  end

  @msg "Incoming log from test with all metadata"
  test "correctly handles metadata keys", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", @path, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      body = TestUtils.decode_logger_body(body)

      assert %{
               "batch" => [
                 %{
                   "message" => @msg,
                   "metadata" => %{
                     "level" => "info",
                     "context" => %{
                       "pid" => pidbinary,
                       "module" => _,
                       "file" => _,
                       "line" => _,
                       "function" => _
                     },
                     "test_context" => _
                   },
                   "timestamp" => _
                 }
                 | _
               ],
               "source" => @source
             } = body

      assert length(body["batch"]) == 45

      Plug.Conn.resp(conn, 200, "")
    end)

    :ok = Logger.configure_backend(@logger_backend, metadata: :all)
    LogflareLogger.context(test_context: %{some_metric: 7331})
    for _n <- 1..45, do: Logger.info(@msg)

    Process.sleep(1_000)
  end
end
