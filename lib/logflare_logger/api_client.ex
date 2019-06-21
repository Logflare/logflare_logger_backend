defmodule LogflareLogger.ApiClient do
  @moduledoc false
  use Tesla, only: [:post], docs: false
  adapter Tesla.Adapter.Hackney, pool: __MODULE__

  @default_api_path "/logs/elixir/logger"

  @callback post_logs(Tesla.Client.t(), list(map), String.t()) ::
              {:ok, Tesla.Env.t()} | {:error, term}

  def new(%{url: url, api_key: api_key}) when is_binary(url) and is_binary(api_key) do
    middlewares = [
      Tesla.Middleware.FollowRedirects,
      {Tesla.Middleware.Headers,
       [
         {"x-api-key", api_key},
         {"content-type", "application/bert"}
       ]},
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Compression, format: "gzip"}
    ]

    Tesla.client(middlewares)
  end

  def post_logs(%Tesla.Client{} = client, batch, source_id) when is_list(batch) do
    body =
      %{"batch" => batch, "source" => source_id}
      |> Bertex.encode()

    Tesla.post(client, api_path(), body)
  end

  def api_path, do: @default_api_path
end
