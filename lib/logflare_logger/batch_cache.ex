defmodule LogflareLogger.BatchCache do
  @moduledoc """
  Caches the batch, dispatches API post request if the batch is larger than configured max batch size or flush is called.

  Doesn't error or drop the message if the API is unresponsive, holds them.

  Uses two separate Etso tables:
  - PendingLoggerEvent: events waiting to be sent
  - InFlightLoggerEvent: events currently being sent to the API

  Write path (`put/2`) goes directly to ETS for performance.
  Flush/clear/reset are serialized through BatchServer.
  """

  alias LogflareLogger.Repo
  alias LogflareLogger.PendingLoggerEvent
  alias LogflareLogger.BatchServer

  # batch limit prevents runaway memory usage if API is unresponsive
  @batch_limit 10_000

  def put(event, config) do
    if GenServer.whereis(Repo) do
      %PendingLoggerEvent{}
      |> PendingLoggerEvent.changeset(%{body: event})
      |> Repo.insert!()

      pending_count = ets_size(PendingLoggerEvent)

      if pending_count > @batch_limit do
        pending_events_asc()
        |> Enum.take(pending_count - @batch_limit)
        |> Enum.each(&Repo.delete/1)
      end

      sync_threshold = min(config.batch_max_size * 4, div(@batch_limit, 2))

      cond do
        pending_count >= sync_threshold ->
          BatchServer.flush(config)

        pending_count >= config.batch_max_size ->
          BatchServer.flush_async(config)

        true ->
          :ok
      end

      {:ok, :insert_successful}
    else
      {:error, :repo_not_found}
    end
  end

  def flush(config), do: BatchServer.flush(config)

  def clear, do: BatchServer.clear()

  defp pending_events_asc do
    Repo.all(PendingLoggerEvent)
    |> Enum.sort_by(& &1.id, &<=/2)
  end

  defp ets_size(schema) do
    {:ok, table} = Etso.Adapter.TableRegistry.get_table(Repo, schema)
    :ets.info(table, :size)
  end
end
