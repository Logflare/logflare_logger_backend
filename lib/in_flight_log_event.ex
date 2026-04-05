defmodule LogflareLogger.InFlightLoggerEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "in_flight_logger_events" do
    field :body, :map
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:body])
  end
end
