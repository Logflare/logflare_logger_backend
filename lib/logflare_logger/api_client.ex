defmodule LogflareLogger.ApiClient do
  use Tesla
  alias Jason, as: JSON

  def new(url) do
    [
      {Tesla.Middleware.BaseUrl, url},
      Tesla.Middleware.JSON
    ]
    |> Tesla.client()
  end

  def post_logs(client, batch) when is_list(batch) do
    Tesla.post(client, api_path(), %{"batch" => batch})
  end

  def api_path, do: "/api/v1/elixir/logger"
end
