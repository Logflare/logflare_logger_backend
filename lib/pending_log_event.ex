defmodule LogflareLogger.PendingLoggerEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "logger_events" do
    field :body, :map
    field :api_request_started_at, :integer, default: 0
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:body, :api_request_started_at])
  end
end
