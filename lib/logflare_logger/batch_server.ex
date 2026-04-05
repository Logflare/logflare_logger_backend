defmodule LogflareLogger.BatchServer do
  @moduledoc """
  Serializes flush, clear, and reset operations on the batch tables.

  `put/2` bypasses this server for performance — it writes directly to ETS.
  """

  use GenServer

  alias LogflareLogger.Repo
  alias LogflareLogger.PendingLoggerEvent
  alias LogflareLogger.InFlightLoggerEvent
  import Ecto.Query

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def flush(config) do
    GenServer.cast(__MODULE__, {:flush, config})
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  def events_in_flight do
    GenServer.call(__MODULE__, :events_in_flight)
  end

  def reset_events_in_flight(events) do
    GenServer.call(__MODULE__, {:reset_events_in_flight, events})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Ensure ETS tables exist so delete_all doesn't crash on empty tables
    Etso.Adapter.TableRegistry.get_table(Repo, PendingLoggerEvent)
    Etso.Adapter.TableRegistry.get_table(Repo, InFlightLoggerEvent)
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:flush, config}, state) do
    do_flush(config)
    {:noreply, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    Repo.delete_all(from(PendingLoggerEvent))
    Repo.delete_all(from(InFlightLoggerEvent))
    {:reply, :ok, state}
  end

  def handle_call(:events_in_flight, _from, state) do
    events = Repo.all(InFlightLoggerEvent)
    {:reply, events, state}
  end

  def handle_call({:reset_events_in_flight, events}, _from, state) do
    bodies = Enum.map(events, &%{body: &1.body})
    Repo.insert_all(PendingLoggerEvent, bodies)

    for e <- events, do: Repo.delete(e)

    {:reply, length(events), state}
  end

  defp do_flush(config) do
    pending_events = Repo.all(PendingLoggerEvent)

    if not Enum.empty?(pending_events) do
      in_flight_maps =
        Enum.map(pending_events, fn ple ->
          %{id: :erlang.unique_integer(), body: ple.body}
        end)

      Repo.insert_all(InFlightLoggerEvent, in_flight_maps)

      in_flight_entries = Enum.map(in_flight_maps, &struct(InFlightLoggerEvent, &1))

      for ple <- pending_events, do: Repo.delete(ple)

      Task.start(fn ->
        in_flight_entries
        |> post_logs(config)
        |> case do
          {:ok, %Tesla.Env{status: status, body: body}} ->
            unless status in 200..299 do
              Logger.warning(
                "Logflare API warning: HTTP response status is #{status}. Response body is: #{inspect(body)}"
              )
            end

            for ife <- in_flight_entries, do: Repo.delete(ife)

          {:error, reason} ->
            Logger.warning("Logflare API error: #{inspect(reason)}")

            reset_events_in_flight(in_flight_entries)

            :noop
        end
      end)
    end
  end

  defp post_logs(events, %{api_client: api_client, source_id: source_id}) do
    bodies = Enum.map(events, & &1.body)
    LogflareApiClient.post_logs(api_client, bodies, source_id)
  end
end
