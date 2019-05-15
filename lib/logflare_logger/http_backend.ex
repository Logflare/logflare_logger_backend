defmodule LogflareLogger.HttpBackend do
  @moduledoc """
  Implements :gen_event behaviour, handles incoming Logger messages
  """
  alias LogflareLogger.Utils
  @behaviour :gen_event
  require Logger
  alias LogflareLogger.{ApiClient, Formatter, BatchCache, CLI, Config}

  @type level :: Logger.level()

  def init(__MODULE__, options \\ []) when is_list(options) do
    config = configure_merge(options, %Config{})
    schedule_flush(config)
    {:ok, config}
  end

  def handle_event(:flush, config) do
    config = flush!(config)
    {:ok, config}
  end

  def handle_event({_, gl, _}, config) when node(gl) != node() do
    {:ok, config}
  end

  def handle_event({level, _gl, {Logger, msg, datetime, metadata}}, %Config{} = config) do
    if log_level_matches?(level, config.level) do
      formatted = format_event(level, msg, datetime, metadata, config)

      BatchCache.put(formatted, config)
    end

    {:ok, config}
  end

  def handle_info(:flush, config) do
    config = flush!(config)
    {:ok, config}
  end

  def handle_info(_term, config) do
    {:ok, config}
  end

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

  # Configuration values is populated according to the following priority list:
  # 1. Dynamically confgiured options with Logger.configure(...)
  # 2. Application environment
  # 3. Current config
  defp configure_merge(options, %Config{} = config) when is_list(options) do
    options =
      :logflare_logger_backend
      |> Application.get_all_env()
      |> Keyword.merge(options)

    url = Keyword.get(options, :url)
    api_key = Keyword.get(options, :api_key)
    source = Keyword.get(options, :source)
    level = Keyword.get(options, :level, config.level)
    format = Keyword.get(options, :format, config.format)
    metadata = Keyword.get(options, :metadata, config.metadata)
    batch_max_size = Keyword.get(options, :max_batch_size, config.batch_max_size)
    flush_interval = Keyword.get(options, :flush_interval, config.flush_interval)

    unless url do
      throw("Logflare API URL for LogflareLogger backend is NOT configured")
    end

    unless api_key do
      throw("Logflare API key for LogflareLogger backend is NOT configured")
    end

    unless source do
      throw("Source parameter for LogflareLogger backend is NOT configured")
    end

    api_client = ApiClient.new(%{url: url, api_key: api_key})

    struct!(
      Config,
      %{
        api_client: api_client,
        source: source,
        level: level,
        format: format,
        metadata: metadata,
        batch_size: config.batch_size,
        batch_max_size: batch_max_size,
        flush_interval: flush_interval
      }
    )
  end

  # Batching and flushing

  defp flush!(%Config{} = config) do
    BatchCache.flush(config)

    schedule_flush(config)
    config
  end

  defp schedule_flush(%Config{} = config) do
    Process.send_after(self(), :flush, config.flush_interval)
  end

  # Events

  @spec log_level_matches?(level, level | nil) :: boolean
  defp log_level_matches?(_lvl, nil), do: true
  defp log_level_matches?(lvl, min), do: Logger.compare_levels(lvl, min) != :lt

  defp format_event(
         level,
         msg,
         ts,
         meta,
         %{format: {Formatter, :format}, metadata: metakeys}
       )
       when is_list(metakeys) do
    keys = Utils.default_metadata_keys() -- metakeys

    meta =
      meta
      |> Enum.into(%{})
      |> Map.drop(keys)

    Formatter.format(level, msg, ts, meta)
  end

  defp format_event(level, msg, ts, meta, %{metadata: :all}) do
    meta =
      meta
      |> Enum.into(%{})

    Formatter.format(level, msg, ts, meta)
  end
end
