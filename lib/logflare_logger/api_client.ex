defmodule LogflareLogger.ApiClient do
  use Tesla

  @callback post_logs(Tesla.Client.t(), list(map), String.t()) ::
              {:ok, Tesla.Env.t()} | {:error, term}

  def new(%{url: url, api_key: api_key}) do
    [
      Tesla.Middleware.FollowRedirects,
      {Tesla.Middleware.Headers,
       [
         {"x-api-key", api_key},
         {"content-type", "application/bert"},
         {"content-encoding", "gzip"}
       ]},
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Compression, format: "gzip"}
    ]
    |> Tesla.client()
  end

  def post_logs(client, batch, source_id) when is_list(batch) do
    body =
      %{"batch" => batch, "source" => source_id}
      |> Iteraptor.jsonify(values: true)
      |> Map.update!("batch", &batch_to_payload/1)
      |> Bertex.encode()

    Tesla.post(client, api_path(), body) 
  end

  def batch_to_payload(batch) do
    for log_entry <- batch do
      metadata =
        %{}
        |> Map.merge(log_entry["context"]["user"] || %{})
        |> Map.put("context", log_entry["context"]["system"] || %{})

      log_entry
      |> Map.put("metadata", metadata)
      |> Map.drop(["context"])
    end
  end

  def api_path, do: "/logs/elixir/logger"
end
