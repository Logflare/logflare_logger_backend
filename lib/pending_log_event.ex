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
    |> update_change(:body, &fix_body/1)
  end

  defp fix_body(change) do
    change
    |> Enum.map(fn {k, v} -> {k, check_deep_struct(v)} end)
    |> Map.new()
  end

  defp check_deep_struct(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {k, check_deep_struct(v)} end)
    |> Map.new()
  end

  defp check_deep_struct(value) when is_list(value) do
    single_type? =
      value
      |> Enum.map(&type/1)
      |> Enum.uniq()
      |> then(&(length(&1) == 1))

    case single_type? do
      true ->
        value

      false ->
        Enum.map(value, fn
          v when is_binary(v) -> v
          v -> inspect(v)
        end)
    end
  end

  defp check_deep_struct(value), do: value

  defp type(v) when is_map(v), do: :map
  defp type(v) when is_list(v), do: :list
  defp type(v) when is_integer(v), do: :integer
  defp type(v) when is_float(v), do: :float
  defp type(v) when is_number(v), do: :number
  defp type(v) when is_binary(v), do: :binary
  defp type(v) when is_boolean(v), do: :boolean
  defp type(_), do: :other
end
