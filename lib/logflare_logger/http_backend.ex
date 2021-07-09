defmodule LogflareLogger.HttpBackend do
  @moduledoc """
  Implements :gen_event behaviour, handles incoming Logger messages
  """

  @default_api_url "https://api.logflare.app"
  @app :logflare_logger_backend
  @behaviour :gen_event

  require Logger
  alias LogflareLogger.{Formatter, BatchCache, CLI}
  alias LogflareLogger.BackendConfig, as: Config

  @type level :: Logger.level()
  @type message :: Logger.message()
  @type metadata :: Logger.metadata()
  @type log_msg :: {level, pid, {Logger, message, term, metadata}} | :flush

  @spec init(__MODULE__, keyword) :: {:ok, Config.t()}
  def init(__MODULE__, options \\ []) when is_list(options) do
    schedule_in_flight_check()
    msg = "#{__MODULE__} v#{Application.spec(@app, :vsn)} started."
    log_after(:info, msg)

    options
    |> configure_merge(%Config{})
    |> schedule_flush()
  end

  @spec handle_event(log_msg, Config.t()) :: {:ok, Config.t()}
  def handle_event(:flush, config), do: flush!(config)

  def handle_event({_, gl, _}, config) when node(gl) != node() do
    {:ok, config}
  end

  def handle_event({level, _gl, {Logger, msg, datetime, metadata}}, %Config{} = config) do
    if log_level_matches?(level, config.level) do
      level
      |> Formatter.format_event(msg, datetime, metadata, config)
      |> BatchCache.put(config)
    end

    {:ok, config}
  end

  def handle_info({:log_after, level, message}, config) do
    Logger.log(level, message)

    {:ok, config}
  end

  def handle_info(:in_flight_check, config) do
    # If we somehow have events in flight stuck in our Repo, they get reset here to get flushed to Logflare.
    if GenServer.whereis(LogflareLogger.Repo) do
      count = BatchCache.events_in_flight() |> BatchCache.reset_events_in_flight() |> Enum.count()

      if count > 0 do
        msg =
          "#{__MODULE__} v#{Application.spec(@app, :vsn)} resetting #{count} log events in flight. If this continues please submit an issue."

        log_after(:warn, msg)
      end
    end

    {:ok, config}
  end

  def handle_info(:flush, config), do: flush!(config)

  def handle_info(_term, config), do: {:ok, config}

  @spec handle_call({:configure, keyword()}, Config.t()) :: {:ok, :ok, Config.t()}
  def handle_call({:configure, options}, %Config{} = config) do
    config = configure_merge(options, config)
    # Makes sure that next flush is done
    # after the configuration update
    # if the flush interval is lower than default or previous config
    schedule_flush(config)
    {:ok, :ok, config}
  end

  def code_change(_old_vsn, config, _extra), do: {:ok, config}

  def terminate(_reason, _state), do: :ok

  @spec configure_merge(keyword, Config.t()) :: Config.t()
  def configure_merge(options, %Config{} = config) when is_list(options) do
    # Configuration values are populated according to the following priorities:
    # 1. Dynamically confgiured options with Logger.configure(...)
    # 2. Application environment
    # 3. System environment
    # 4. Current config

    sys_options = System.get_env() |> find_logflare_sys_envs()
    app_options = Application.get_all_env(@app)

    options =
      app_options
      |> Keyword.merge(sys_options)
      |> Keyword.merge(options)

    url = Keyword.get(options, :url) || @default_api_url
    api_key = Keyword.get(options, :api_key)
    source_id = Keyword.get(options, :source_id)
    level = Keyword.get(options, :level, config.level)
    format = Keyword.get(options, :format, config.format)
    metadata = Keyword.get(options, :metadata, config.metadata)
    batch_max_size = Keyword.get(options, :batch_max_size, config.batch_max_size)
    flush_interval = Keyword.get(options, :flush_interval, config.flush_interval)

    CLI.throw_on_missing_url!(url)
    CLI.throw_on_missing_source!(source_id)
    CLI.throw_on_missing_api_key!(api_key)

    api_client = LogflareApiClient.new(%{url: url, api_key: api_key})

    config =
      struct!(
        Config,
        %{
          api_client: api_client,
          source_id: source_id,
          level: level,
          format: format,
          metadata: metadata,
          batch_size: config.batch_size,
          batch_max_size: batch_max_size,
          flush_interval: flush_interval
        }
      )

    if :ets.info(:logflare_logger_table) === :undefined do
      :ets.new(:logflare_logger_table, [:named_table, :set, :public])
    end

    :ets.insert(:logflare_logger_table, {:config, config})

    config
  end

  # Batching and flushing

  @spec flush!(Config.t()) :: {:ok, Config.t()}
  defp flush!(%Config{} = config) do
    if GenServer.whereis(LogflareLogger.Repo) do
      BatchCache.flush(config)
    end

    schedule_flush(config)
  end

  @spec schedule_flush(Config.t()) :: {:ok, Config.t()}
  defp schedule_flush(%Config{} = config) do
    Process.send_after(self(), :flush, config.flush_interval)
    {:ok, config}
  end

  defp schedule_in_flight_check() do
    Process.send_after(self(), :in_flight_check, 0)
  end

  defp log_after(level, message, delay \\ 5_000) do
    # We'd like to see these in Logflare so we delay the log message to make sure Logger and the Logflare backend has been started
    Process.send_after(self(), {:log_after, level, message}, delay)
  end

  # Events

  @spec log_level_matches?(level, level | nil) :: boolean
  defp log_level_matches?(_lvl, nil), do: true
  defp log_level_matches?(lvl, min), do: Logger.compare_levels(lvl, min) != :lt

  defp find_logflare_sys_envs(envs) do
    Enum.map(envs, fn {k, v} ->
      case String.split(k, "LOGFLARE_") do
        ["", key] ->
          k = String.downcase(key) |> String.to_atom()
          {k, v}

        _ ->
          nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
  end
end
