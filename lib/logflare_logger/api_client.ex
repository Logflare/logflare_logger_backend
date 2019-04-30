defmodule LogflareLogger.ApiClient do
  use Tesla
  alias LogflareLogger.Cache

  def new(%{url: url, api_key: api_key}) do
    [
      {Tesla.Middleware.Headers, [{"x-api-key", api_key}]},
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Compression, format: "gzip"},
      Tesla.Middleware.JSON
    ]
    |> Tesla.client()
  end

  def post_logs(client, batch) when is_list(batch) do
    source = Cache.get_config(:source)
    Tesla.post(client, api_path(), %{"batch" => batch, "source" => source})
  end

  def api_path, do: "/api/v1/elixir/logger"
end
