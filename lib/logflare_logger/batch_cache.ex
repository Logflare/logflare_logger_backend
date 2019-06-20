defmodule LogflareLogger.BatchCache do
  @moduledoc """
  Caches the batch, dispatches API post request if the batch is larger than configured max batch size or flush is called.

  Doesn't error or drop the message if the API is unresponsive, holds them
  """
  @batch :batch
  @cache __MODULE__
  alias LogflareLogger.{ApiClient}
  # batch limit prevents runaway memory usage if API is unresponsive
  @batch_limit 10_000

  def put_initial do
    Cachex.put!(@cache, @batch, %{
      count: 0,
      events: []
    })
  end

  def put(event, config) do
    new_batch =
      Cachex.get_and_update!(@cache, @batch, fn %{count: c, events: events} ->
        events =
          [event | events]
          |> Enum.take(@batch_limit)

        count =
          if c + 1 > @batch_limit do
            @batch_limit
          else
            c + 1
          end

        %{count: count, events: events}
      end)

    if new_batch.count >= config.batch_max_size do
      flush(config)
    end

    new_batch
  end

  def flush(config) do
    batch = get!()

    if batch.count > 0 do
      batch.events
      |> Enum.reverse()
      |> post_logs(config)
      |> case do
        {:ok, %Tesla.Env{status: _}} ->
          get_and_update!(fn %{count: c, events: events} ->
            events = events -- batch.events
            %{count: c - batch.count, events: events}
          end)

        {:error, reason} ->
          IO.warn("Logflare API error: #{inspect(reason)}")
          :noop
      end
    end
  end

  defp get_and_update!(fun) do
    Cachex.get_and_update!(@cache, @batch, fun)
  end

  def get!() do
    Cachex.get!(@cache, @batch)
  end

  def post_logs(events, %{api_client: api_client, source_id: source_id}) do
    mod =
      if Application.get_env(:logflare_env, :test_env)[:api_client] do
        ApiClientMock
      else
        ApiClient
      end

    mod.post_logs(api_client, events, source_id)
  end

  def put_config(config) do
    Cachex.put!(@cache, :config, config)
  end

  def get_config() do
    Cachex.get!(@cache, :config)
  end
end
