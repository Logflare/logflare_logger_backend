defmodule LogflareLogger.HttpBackend do
  @moduledoc """
  Implements :gen_event behaviour, handles incoming Logger messages
  """
  @behaviour :gen_event
  @default_batch_size 1000
  @default_flush_interval 500
  require Logger
  alias LogflareLogger.{ApiClient, Formatter, Cache}

  @default_config %{
    level: :info,
    format: {Formatter, :format},
    metadata: [],
    batch: %{
      size: 0,
      max_size: @default_batch_size
    },
    flush: %{
      interval: @default_flush_interval
    }
  }

  # TypeSpecs

  @type level :: Logger.level()

  def init(__MODULE__, options \\ []) when is_list(options) do
    state = configure(options, @default_config)
    schedule_flush(state)
    {:ok, state}
  end

  def handle_event({_level, gl, _msg}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, datetime, metadata}}, state) do
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

  def handle_call({:configure, options}, state) do
    state = configure(options, state)
    {:ok, :ok, state}
  end

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(_reason, _state), do: :ok

  defp configure(options, state) do
    url = Keyword.get(options, :url, Cache.config_url())
    level = Keyword.get(options, :level, state.level)
    format = Keyword.get(options, :format, state.format)
    metadata = Keyword.get(options, :metadata, state.metadata)
    max_batch_size = Keyword.get(options, :max_batch_size, state.batch.max_size)
    flush_interval = Keyword.get(options, :flush_interval, state.flush.interval)

    api_client = ApiClient.new(url)

    %{
      api_client: api_client,
      level: level,
      format: format,
      metadata: metadata,
      batch: %{
        size: state.batch.size,
        max_size: max_batch_size
      },
      flush: %{
        interval: flush_interval
      }
    }
  end

  # Batching and flushing

  def batch_ready?(%{batch: %{size: size, max_size: max_size}}) do
    size >= max_size
  end

  def update_batch(event, state) do
    _ = Cache.add_event_to_batch(event)
    update_in(state.batch.size, &(&1 + 1))
  end

  defp flush!(%{batch: %{size: 0}} = state) do
    schedule_flush(state)
    state
  end

  defp flush!(state) do
    batch = Cache.get_batch()

    {:ok, _} = ApiClient.post_logs(state.api_client, batch)

    _ = Cache.reset_batch()
    state = put_in(state.batch.size, 0)

    schedule_flush(state)
    state
  end

  defp schedule_flush(state) do
    Process.send_after(self(), :flush, state.flush.interval)
  end

  # API

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
    meta = meta |> Enum.into(%{}) |> Map.take(state.metadata)
    Formatter.format(level, msg, ts, meta)
  end

  defp format_event(level, msg, ts, meta, %{metadata: :all}) do
    meta = meta |> Enum.into(%{})
    Formatter.format(level, msg, ts, meta)
  end
end
