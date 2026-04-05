defmodule LogflareLogger.BatchCache do
  @moduledoc """
  Caches the batch, dispatches API post request if the batch is larger than configured max batch size or flush is called.

  Doesn't error or drop the message if the API is unresponsive, holds them.

  Uses two separate Etso tables:
  - PendingLoggerEvent: events waiting to be sent
  - InFlightLoggerEvent: events currently being sent to the API
  """

  alias LogflareLogger.Repo
  alias LogflareLogger.PendingLoggerEvent
  alias LogflareLogger.InFlightLoggerEvent

  require Logger

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

      if pending_count >= config.batch_max_size do
        flush(config)
      end

      {:ok, :insert_successful}
    else
      {:error, :repo_not_found}
    end
  end

  def flush(config) do
    pending_events = pending_events_asc()

    if not Enum.empty?(pending_events) do
      in_flight =
        Enum.map(pending_events, fn ple ->
          {:ok, ife} =
            %InFlightLoggerEvent{}
            |> InFlightLoggerEvent.changeset(%{body: ple.body})
            |> Repo.insert()

          Repo.delete!(ple)
          ife
        end)

      Task.start(fn ->
        in_flight
        |> post_logs(config)
        |> case do
          {:ok, %Tesla.Env{status: status, body: body}} ->
            unless status in 200..299 do
              Logger.warning(
                "Logflare API warning: HTTP response status is #{status}. Response body is: #{inspect(body)}"
              )
            end

            for ife <- in_flight do
              Repo.delete(ife)
            end

          {:error, reason} ->
            Logger.warning("Logflare API error: #{inspect(reason)}")

            reset_events_in_flight(in_flight)

            :noop
        end
      end)
    else
      :noop
    end
  end

  def clear do
    Repo.all(PendingLoggerEvent) |> Enum.each(&Repo.delete/1)
    Repo.all(InFlightLoggerEvent) |> Enum.each(&Repo.delete/1)
  end

  def post_logs(events, %{api_client: api_client, source_id: source_id}) do
    events = Enum.map(events, & &1.body)
    LogflareApiClient.post_logs(api_client, events, source_id)
  end

  def events_in_flight() do
    Repo.all(InFlightLoggerEvent)
    |> sort_by_created_asc()
  end

  def reset_events_in_flight(events) do
    for e <- events do
      {:ok, ple} =
        %PendingLoggerEvent{}
        |> PendingLoggerEvent.changeset(%{body: e.body})
        |> Repo.insert()

      Repo.delete(e)
      ple
    end
  end

  defp pending_events_asc do
    Repo.all(PendingLoggerEvent)
    |> sort_by_created_asc()
  end

  defp sort_by_created_asc(events) do
    # etso id is System.monotonic_time
    Enum.sort_by(events, & &1.id, &<=/2)
  end

  defp ets_size(schema) do
    {:ok, table} = Etso.Adapter.TableRegistry.get_table(Repo, schema)
    :ets.info(table, :size)
  end
end
