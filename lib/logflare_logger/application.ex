defmodule LogflareLogger.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      LogflareLogger.Repo
    ]

    opts = [strategy: :one_for_one, name: LogflareLogger.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
