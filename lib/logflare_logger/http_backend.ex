defmodule LogflareLogger.Backend do
  @moduledoc """
  Implements :gen_event behaviour, handles incoming Logger messages
  """
  @behaviour :gen_event
  alias LogflareLogger.{ApiClient, Formatter}

  # TypeSpecs

  @type level :: Logger.level()

  def init({__MODULE__, options}) do
    {:ok, configure(options, [])}
  end

  def handle_event({_level, gl, _msg}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, datetime, metadata}}, state) do
    if log_level_matches?(level, state.min_level) do
      formatted = format_event(level, msg, datetime, metadata, state)
      {:ok, _} = ApiClient.post_logs(state.api_client, formatted)
      {:ok, state}
    else
      {:ok, state}
    end
  end

  def handle_event(:flush, state), do: {:ok, state}

  def handle_call({:configure, options}, state) do
    {:ok, :ok, configure(options, state)}
  end

  def handle_info(_, state), do: {:ok, state}

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(_reason, _state), do: :ok

  defp configure(options, _state) when is_list(options) do
    port = Keyword.get(options, :port)
    host = Keyword.get(options, :host)
    level = Keyword.get(options, :level)
    format = Keyword.get(options, :format)
    metadata = Keyword.get(options, :metadata)
    max_batch_size = Keyword.get(options, :max_batch_size)
    api_client = ApiClient.new(%{port: port, host: host})

    %{
      api_client: api_client,
      min_level: level,
      format: format,
      metadata: metadata,
      batch: %{
        size: 0,
        max_size: 0 || max_batch_size
      }
    }
  end

  defp configure(:test, _state) do
    %{}
  end

  # Batching and flushing

  def batch_ready?(%{batch: %{size: size, max_size: max_size}}) do
    size >= max_size
  end

  def update_batch(event, state) do
    _ = Cache.add_event_to_batch(event)
    update_in(state.batch.size, &(&1 + 1))
  end

  defp flush!(state) do
    batch = Cache.get_batch()

    if length(batch) > 0 do
      {:ok, _} = ApiClient.post_logs(state.api_client, batch)
      _ = Cache.reset_batch()
      put_in(state.batch.size, 0)
    end
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
