defmodule LogflareLogger.ApiClient do
  use Tesla

  def new(%{url: url, api_key: api_key}) do
    [
      {Tesla.Middleware.Headers, [{"x-api-key", api_key}]},
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Compression, format: "gzip"},
      Tesla.Middleware.JSON
    ]
    |> Tesla.client()
  end

  def post_logs(client, batch, source) when is_list(batch) do
    Tesla.post(client, api_path(), %{"batch" => batch, "source" => source})
  end

  def api_path, do: "/api/v1/elixir/logger"
end
