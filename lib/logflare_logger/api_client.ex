defmodule LogflareLogger.ApiClient do
  use Tesla

  def new(%{url: url, api_key: api_key}) do
    [
      Tesla.Middleware.FollowRedirects,
      {Tesla.Middleware.Headers, [{"x-api-key", api_key}]},
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Compression, format: "gzip"}
    ]
    |> Tesla.client()
  end

  def post_logs(client, batch, source) when is_list(batch) do
    body =
      %{"batch" => batch, "source_name" => source}
      |> Iteraptor.jsonify(values: true)
      |> Bertex.encode()

    Tesla.post(client, api_path(), body)
  end

  def atoms_to_strings() do
  end

  def api_path, do: "/logs/elixir/logger"
end
