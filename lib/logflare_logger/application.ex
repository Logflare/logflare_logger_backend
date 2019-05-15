defmodule LogflareLogger.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Cachex, LogflareLogger.BatchCache}
    ]

    opts = [strategy: :one_for_one, name: LogflareLogger.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)
    LogflareLogger.BatchCache.put_initial()
    {:ok, pid}
  end
end
