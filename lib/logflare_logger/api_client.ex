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
    Tesla.post(client, elixir_logger_path(), %{"batch" => batch}) 
  end

  def elixir_logger_path, do: "/api/v0/elixir-logger"
end
