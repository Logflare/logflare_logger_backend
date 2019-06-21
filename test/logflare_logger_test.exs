defmodule LogflareLoggerTest do
  @moduledoc false
  alias LogflareLogger.{ApiClient, HttpBackend}
  use ExUnit.Case
  import LogflareLogger
  doctest LogflareLogger
  use Placebo
  require Logger

  @logger_backend HttpBackend
  @api_key "l3kh47jsakf2370dasg"
  @source "source2354551"

  setup_all do
    Application.put_env(:logflare_logger_backend, :url, "http://127.0.0.1:4000")
    Application.put_env(:logflare_logger_backend, :api_key, @api_key)
    Application.put_env(:logflare_logger_backend, :source_id, @source)
    Application.put_env(:logflare_logger_backend, :level, :info)
    Application.put_env(:logflare_logger_backend, :flush_interval, 100)
    Application.put_env(:logflare_logger_backend, :max_batch_size, 2)
    {:ok, _pid} = Logger.add_backend(@logger_backend)

    on_exit(&LogflareLogger.delete_context/0)
    :ok
  end

  describe "debug, info, warn, error functions" do
    test "uses same configuration as Logger functions" do
      allow ApiClient.new(any()), return: %Tesla.Client{}
      allow ApiClient.post_logs(any(), any(), any()), return: {:ok, %Tesla.Env{status: 200}}

      LogflareLogger.merge_context(%{context_key: [:context_value, 1, "string"]})
      Logger.bare_log(:info, "msg", data: %{a: 1})
      LogflareLogger.info("msg", data: %{a: 1})

      Process.sleep(200)

      assert_called ApiClient.post_logs(
                      any,
                      is(fn [logger, logflare_logger] ->
                        assert Map.drop(logger, ~w[timestamp]) ==
                                 Map.drop(logflare_logger, ~w[timestamp])
                      end),
                      any
                    )
    end
  end

  describe "Context" do
    test "gets, sets and unsets one context key" do
      assert get_context() == %{}

      assert merge_context(advanced_logging: true) == %{advanced_logging: true}
      assert merge_context(advanced_logging: false) == %{advanced_logging: false}

      assert merge_context(simple_logging: true) == %{
               simple_logging: true,
               advanced_logging: false
             }

      assert get_context() == %{simple_logging: true, advanced_logging: false}

      :ok = delete_context(:simple_logging)
      :ok = delete_context(:advanced_logging)
      assert get_context() == %{}
    end

    test "gets, sets and unsets multiple context keys" do
      assert get_context() == %{}

      assert merge_context(key1: 1, key2: 2) == %{key1: 1, key2: 2}
      assert merge_context(key2: 3, key4: 4) == %{key1: 1, key2: 3, key4: 4}
      assert get_context() == %{key1: 1, key2: 3, key4: 4}

      :ok = delete_context()
      assert get_context() == %{}
    end

    test "set context raises for invalid values" do
      assert_raise FunctionClauseError, fn ->
        merge_context(nil)
      end

      assert_raise FunctionClauseError, fn ->
        merge_context(false)
      end

      assert_raise FunctionClauseError, fn ->
        merge_context(1_000)
      end
    end
  end
end
