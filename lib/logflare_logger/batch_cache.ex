defmodule LogflareLogger.BatchCache do
  @moduledoc """
  Caches the batch, dispatches API post request if the batch is larger than configured max batch size or flush is called.

  Doesn't error or drop the message if the API is unresponsive, holds them
  """

  alias LogflareLogger.Repo
  alias LogflareLogger.PendingLoggerEvent
  import Ecto.Query

  require Logger

  # batch limit prevents runaway memory usage if API is unresponsive
  @batch_limit 10_000

  def put(event, _config) do
    if GenServer.whereis(Repo) do
      %PendingLoggerEvent{}
      |> PendingLoggerEvent.changeset(%{body: event})
      |> Repo.insert!()

      {:ok, :insert_successful}
    else
      {:error, :repo_not_found}
    end
  end

  def flush(config) do
    api_request_started_at = System.monotonic_time()

    pending_events = pending_events_not_in_flight()
    pending_count = length(pending_events)

    pending_events =
      if pending_count > @batch_limit do
        excess = pending_count - @batch_limit
        {to_drop, to_keep} = Enum.split(pending_events, excess)
        Enum.each(to_drop, &Repo.delete/1)
        to_keep
      else
        pending_events
      end

    if not Enum.empty?(pending_events) do
      ples =
        pending_events
        |> Enum.map(fn ple ->
          {:ok, ple} =
            ple
            |> PendingLoggerEvent.changeset(%{api_request_started_at: api_request_started_at})
            |> Repo.update()

          ple
        end)

      flushed_count = length(ples)
      caller = self()

      Task.start(fn ->
        ples
        |> post_logs(config)
        |> case do
          {:ok, %Tesla.Env{status: status, body: body}} ->
            unless status in 200..299 do
              Logger.warning(
                "Logflare API warning: HTTP response status is #{status}. Response body is: #{inspect(body)}"
              )
            end

            for ple <- ples do
              Repo.delete(ple)
            end

          {:error, reason} ->
            Logger.warning("Logflare API error: #{inspect(reason)}")

            reset_events_in_flight(ples)
            :gen_event.notify(caller, :flush_failed)

            :noop
        end
      end)

      {:ok, flushed_count}
    else
      {:ok, 0}
    end
  end

  def clear do
    Repo.all(PendingLoggerEvent) |> Enum.map(&Repo.delete(&1))
  end

  def post_logs(events, %{api_client: api_client, source_id: source_id}) do
    events = Enum.map(events, & &1.body)
    LogflareApiClient.post_logs(api_client, events, source_id)
  end

  def sort_by_created_asc(pending_events) do
    # etso id is System.monotonic_time
    Enum.sort_by(pending_events, & &1.id, &<=/2)
  end

  def events_in_flight() do
    from(PendingLoggerEvent)
    |> where([le], le.api_request_started_at != 0)
    |> Repo.all()
    |> sort_by_created_asc()
  end

  def pending_events_not_in_flight() do
    from(PendingLoggerEvent)
    |> where([le], le.api_request_started_at == 0)
    |> Repo.all()
    |> sort_by_created_asc()
  end

  def reset_events_in_flight(events) do
    for e <- events do
      e
      |> PendingLoggerEvent.changeset(%{api_request_started_at: 0})
      |> Repo.update()
    end
  end
end
