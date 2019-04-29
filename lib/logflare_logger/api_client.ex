defmodule LogflareLogger.ApiClient do
  use Tesla
  alias Jason, as: JSON

  def new(%{host: host, port: port}) do
    middleware = [
      {Tesla.Middleware.BaseUrl, "http://#{host}:#{port}"},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  def post_logs(client, batch) when is_list(batch) do
    json = JSON.encode!(batch)
    Tesla.post(client, elixir_logger_path(), json)
  end

  def elixir_logger_path, do: "/api/v0/elixir-logger"
end
