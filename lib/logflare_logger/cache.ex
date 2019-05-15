defmodule LogflareLogger.BatchCache do
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
        events = Enum.take([event | events], @batch_limit)
        %{count: c + 1, events: events}
      end)

    if new_batch.count >= config.batch_max_size do
      flush(config)
    end
  end

  def flush(config) do
    batch = get!()

    with {:count, true} <- {:count, batch.count > 0},
         {:api, {:ok, %Tesla.Env{status: 200}}} <- {:api, post_logs(batch.events, config)} do
      get_and_update!(fn %{count: c, events: events} ->
        events = events -- batch.events
        %{count: c - batch.count, events: events}
      end)
    else
      {:api, {_, _tesla_env}} -> :noop
      {:count, _} -> :noop
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
end
