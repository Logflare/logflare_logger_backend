defmodule LogflareLogger.BatchCache do
  @moduledoc """
  Caches the batch, dispatches API post request if the batch is larger than configured max batch size or flush is called.

  Doesn't error or drop the message if the API is unresponsive, holds them
  """

  alias LogflareLogger.Repo
  alias LogflareLogger.PendingLoggerEvent
  import Ecto.Query

  # batch limit prevents runaway memory usage if API is unresponsive
  @batch_limit 1_000

  def put(event, config) do
    Repo.insert!(%PendingLoggerEvent{body: event})

    pending_events = Repo.all(PendingLoggerEvent) |> Enum.sort_by(& &1.id, :asc)
    pending_events_count = Enum.count(pending_events)

    if pending_events_count > @batch_limit do
      pending_events
      |> Enum.take(pending_events_count - @batch_limit)
      |> Enum.each(&Repo.delete/1)
    end

    events = Repo.all(PendingLoggerEvent) |> Enum.sort_by(& &1.id, :desc) |> Enum.map(& &1.body)
    events_count = Enum.count(events)
    new_batch = %{events: events, count: events_count}

    if new_batch.count >= config.batch_max_size do
      flush(config)
    end

    new_batch
  end

  def flush(config) do
    api_request_started_at = System.monotonic_time()

    pending_events_not_in_flight =
      from(PendingLoggerEvent)
      |> where([le], le.api_request_started_at == 0)
      |> Repo.all()

    if not Enum.empty?(pending_events_not_in_flight) do
      ples =
        pending_events_not_in_flight
        |> Enum.map(fn ple ->
          {:ok, ple} =
            ple
            |> PendingLoggerEvent.changeset(%{api_request_started_at: api_request_started_at})
            |> Repo.update()

          ple
        end)

      Task.start(fn ->
        ples
        |> post_logs(config)
        |> case do
          {:ok, %Tesla.Env{status: status}} ->
            unless status == 200 do
              IO.warn("Logflare API warning: HTTP response status is #{status}")
            end

            for ple <- ples do
              Repo.delete(ple)
            end

          {:error, reason} ->
            IO.warn("Logflare API error: #{inspect(reason)}")

            for ple <- ples do
              ple
              |> PendingLoggerEvent.changeset(%{api_request_started_at: 0})
              |> Repo.update()
            end

            :noop
        end
      end)
    else
      :noop
    end
  end

  def clear do
    Repo.all(PendingLoggerEvent) |> Enum.map(&Repo.delete(&1))
  end

  def post_logs(events, %{api_client: api_client, source_id: source_id}) do
    events = Enum.map(events, & &1.body)
    LogflareApiClient.post_logs(api_client, events, source_id)
  end
end
