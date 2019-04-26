defmodule LogflareLogger.ApiClient do
  use Tesla

  def new(%{host: host, port: port}) do
    middleware = [
      {Tesla.Middleware.BaseUrl, "http://#{host}:#{port}"},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  def post_logs(client, msg) do
    Tesla.post(client, elixir_logger_path(), msg)
  end

  def elixir_logger_path, do: "/api/v0/elixir-logger"
end
