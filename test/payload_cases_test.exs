defmodule LogflareLogger.PayloadCasesTest do
  @moduledoc false
  use ExUnit.Case
  alias LogflareLogger.{ApiClient, HttpBackend}
  require Logger
  use Placebo

  @logger_backend HttpBackend
  @api_key "test_api_key"
  @source "dad2a85c-683e-4150-abf1-f3001cf39e57"

  setup do
    Application.put_env(:logflare_logger_backend, :url, "http://127.0.0.1:4000")
    Application.put_env(:logflare_logger_backend, :api_key, @api_key)
    Application.put_env(:logflare_logger_backend, :source_id, @source)
    Application.put_env(:logflare_logger_backend, :level, :info)
    Application.put_env(:logflare_logger_backend, :flush_interval, 100)
    Application.put_env(:logflare_logger_backend, :batch_max_size, 1)

    Logger.add_backend(@logger_backend)

    on_exit(fn ->
      Logger.remove_backend(@logger_backend, flush: true)
    end)

    :ok
  end

  describe "payload edge cases" do
    test "simple tuple" do
      allow(ApiClient.new(any()), return: %Tesla.Client{})
      allow(ApiClient.post_logs(any(), any(), any()), return: {:ok, %Tesla.Env{status: 200}})
      members = ["chase", "bob", "drew"]

      Logger.info("Test list!",
        test_list: List.to_tuple(members)
      )

      Process.sleep(100)
      assert_called(ApiClient.post_logs(any(), any(), any()))
    end
  end
end
