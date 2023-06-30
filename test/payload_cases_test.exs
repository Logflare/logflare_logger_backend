defmodule LogflareLogger.PayloadCasesTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias LogflareLogger.HttpBackend
  require Logger
  use Placebo

  @logger_backend HttpBackend
  @api_key "test_api_key"
  @source "dad2a85c-683e-4150-abf1-f3001cf39e57"

  setup do
    url = Application.get_env(:logflare_logger_backend, :url)
    api_key = Application.get_env(:logflare_logger_backend, :api_key)
    source_id = Application.get_env(:logflare_logger_backend, :source_id)
    level = Application.get_env(:logflare_logger_backend, :level)
    flush_interval = Application.get_env(:logflare_logger_backend, :flush_interval)
    max_batch_size = Application.get_env(:logflare_logger_backend, :max_batch_size)

    Application.put_env(:logflare_logger_backend, :url, "http://127.0.0.1:4000")
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

    :ok
  end

  describe "payload edge cases" do
    test "simple tuple" do
      allow(LogflareApiClient.new(any()), return: %Tesla.Client{})

      allow(LogflareApiClient.post_logs(any(), any(), any()),
        return: {:ok, %Tesla.Env{status: 200}}
      )

      members = ["chase", "bob", "drew"]

      Logger.info("Test list!",
        test_list: List.to_tuple(members)
      )

      Process.sleep(500)
      assert_called(LogflareApiClient.post_logs(any(), any(), any()))
    end
  end
end
