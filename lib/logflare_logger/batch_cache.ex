defmodule LogflareLogger.BatchCache do
  @moduledoc """
  Caches the batch, dispatches API post request if the batch is larger than configured max batch size or flush is called.

  Doesn't error or drop the message if the API is unresponsive, holds them
  """

  @cache __MODULE__
  use Agent

  alias LogflareLogger.{ApiClient}

  # batch limit prevents runaway memory usage if API is unresponsive
  @batch_limit 1_000

  def start_link(_) do
    Agent.start_link(fn -> initial_state() end, name: @cache)
  end

  def put(event, config) do
    if pid = Process.whereis(@cache) do
      new_batch =
        Agent.get_and_update(pid, fn %{count: c, events: events} ->
          events = Enum.take([event | events], @batch_limit)
          count = if c + 1 > @batch_limit, do: @batch_limit, else: c + 1
          batch = %{count: count, events: events}
          {batch, batch}
        end)

      if new_batch.count >= config.batch_max_size do
        flush(config)
      end

      new_batch
    else
      nil
    end
  end

  def flush(config) do
    with pid when pid != nil <- Process.whereis(@cache),
         %{count: count, events: events} when count > 0 <- Agent.get(pid, & &1) do
      events
      |> Enum.reverse()
      |> post_logs(config)
      |> case do
        {:ok, %Tesla.Env{status: status}} ->
          unless status == 200 do
            IO.warn("Logflare API warning: HTTP response status is #{status}")
          end

          Agent.update(pid, fn %{count: batched_count, events: batched_events} ->
            %{count: batched_count - count, events: batched_events -- events}
          end)

        {:error, reason} ->
          IO.warn("Logflare API error: #{inspect(reason)}")
          :noop
      end
    else
      _ -> :noop
    end
  end

  def clear do
    Agent.update(@cache, fn _ -> initial_state() end)
  end

  defp initial_state() do
    %{count: 0, events: []}
  end

  def post_logs(events, %{api_client: api_client, source_id: source_id}) do
    ApiClient.post_logs(api_client, events, source_id)
  end
end
