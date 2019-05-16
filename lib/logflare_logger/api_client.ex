defmodule LogflareLogger.ApiClient do
  @moduledoc false
  use Tesla, only: [:post], docs: false
  @default_api_path "/logs/elixir/logger"

  @callback post_logs(Tesla.Client.t(), list(map), String.t()) ::
              {:ok, Tesla.Env.t()} | {:error, term}

  def new(%{url: url, api_key: api_key}) when is_binary(url) and is_binary(api_key) do
    middlewares = [
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

    Tesla.client(middlewares)
  end

  def post_logs(%Tesla.Client{} = client, batch, source_id) when is_list(batch) do
    body =
      %{"batch" => batch, "source" => source_id}
      # jsonify deeply converts all keywords to maps and all atoms to strings
      # for Logflare server to be able to safely convert binary to terms
      # using :erlang.binary_to_term(binary, [:safe])
      |> Iteraptor.jsonify(values: true)
      |> Map.update!("batch", &batch_to_payload/1)
      |> Bertex.encode()

    Tesla.post(client, api_path(), body)
  end

  def batch_to_payload(batch) when is_list(batch) do
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

  def api_path, do: @default_api_path
end
