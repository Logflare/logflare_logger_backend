defmodule LogflareLogger.HttpBackend do
  @moduledoc """
  Implements :gen_event behaviour, handles incoming Logger messages
  """
  @behaviour :gen_event
  @default_batch_size 100
  @default_flush_interval 5000
  require Logger
  alias LogflareLogger.{ApiClient, Formatter, Cache}

  use TypedStruct

  # TypeSpecs

  typedstruct do
    field(:api_client, Tesla.Client.t())
    field(:format, {atom, atom}, default: {Formatter, :format})
    field(:level, atom, default: :info)
    field(:metadata, list(atom), default: [])
    field(:batch_max_size, non_neg_integer, default: @default_batch_size)
    field(:batch_size, non_neg_integer, default: 0)
    field(:flush_interval, non_neg_integer, default: @default_flush_interval)
  end

  @type level :: Logger.level()

  def init(__MODULE__, options \\ []) when is_list(options) do
    config = configure_merge(options, %__MODULE__{})
    schedule_flush(config)
    {:ok, config}
  end

  def handle_event({_level, gl, _msg}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, datetime, metadata}}, %__MODULE__{} = state) do
    state =
      if log_level_matches?(level, state.level) do
        formatted = format_event(level, msg, datetime, metadata, state)
        state = update_batch(formatted, state)

        if batch_ready?(state) do
          flush!(state)
        else
          state
        end
      else
        state
      end

    {:ok, state}
  end

  def handle_event(:flush, state) do
    state = flush!(state)
    {:ok, state}
  end

  def handle_info(:flush, state) do
    state = flush!(state)
    {:ok, state}
  end

  def handle_info(_term, state) do
    {:ok, state}
  end

  def handle_call({:configure, options}, %__MODULE__{} = state) do
    state = configure_merge(options, state)
    # Makes sure that next flush is done
    # after the configuration update
    # if the flush interval is lower than default or previous config
    schedule_flush(state)
    {:ok, :ok, state}
  end

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(_reason, _state), do: :ok

  defp configure_merge(options, state) do
    options = Keyword.merge(Application.get_all_env(:logflare_logger), options)

    url = Keyword.get(options, :url)
    level = Keyword.get(options, :level, state.level)
    format = Keyword.get(options, :format, state.format)
    metadata = Keyword.get(options, :metadata, state.metadata)
    batch_max_size = Keyword.get(options, :max_batch_size, state.batch_max_size)
    flush_interval = Keyword.get(options, :flush_interval, state.flush_interval)

    unless url do
      throw("API URL for LogflareLogger backend is NOT configured")
    end

    unless api_key do
      throw("API key for LogflareLogger backend is NOT configured")
    end

    api_client = ApiClient.new(%{url: url, api_key: api_key})

    struct!(__MODULE__, %{
      api_client: api_client,
      level: level,
      format: format,
      metadata: metadata,
      batch_size: state.batch_size,
      batch_max_size: batch_max_size,
      flush_interval: flush_interval
    })
  end

  # Batching and flushing

  def batch_ready?(%__MODULE__{batch_size: size, batch_max_size: max_size}) do
    size >= max_size
  end

  def update_batch(event, %__MODULE__{} = state) do
    _ = Cache.add_event_to_batch(event)
    update_in(state.batch_size, &(&1 + 1))
  end

  defp flush!(%__MODULE__{batch_size: 0} = state) do
    schedule_flush(state)
    state
  end

  defp flush!(%__MODULE__{} = state) do
    batch = Cache.get_batch()

    {:ok, _} = ApiClient.post_logs(state.api_client, batch)

    _ = Cache.reset_batch()
    state = put_in(state.batch_size, 0)

    schedule_flush(state)
    state
  end

  defp schedule_flush(%__MODULE__{} = state) do
    Process.send_after(self(), :flush, state.flush_interval)
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
         %{format: {Formatter, :format}, metadata: metakeys} = state
       )
       when is_list(metakeys) do
    meta =
      meta
      |> Enum.into(%{})
      |> Map.take(state.metadata)

    Formatter.format(level, msg, ts, meta)
  end

  defp format_event(level, msg, ts, meta, %{metadata: :all}) do
    meta =
      meta
      |> Enum.into(%{})

    Formatter.format(level, msg, ts, meta)
  end
end
