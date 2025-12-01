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

  defp check_deep_struct(%Date{} = value), do: Date.to_iso8601(value)
  defp check_deep_struct(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp check_deep_struct(%Time{} = value), do: Time.to_iso8601(value)
  defp check_deep_struct(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp check_deep_struct(value) when is_struct(value), do: safe_encode(value, :transform)

  defp check_deep_struct(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {k, check_deep_struct(v)} end)
    |> Map.new()
  end

  defp check_deep_struct([]), do: []

  defp check_deep_struct(value) when is_list(value) do
    has_nested_lists? = contains_nested_lists?(value)
    types = value |> Enum.map(&type/1) |> Enum.uniq()
    single_type? = length(types) == 1
    first_type = if single_type?, do: List.first(types), else: nil

    cond do
      has_nested_lists? ->
        safe_encode(value, :transform)

      not single_type? ->
        Enum.map(value, &safe_encode(&1, :transform))

      is_primitive_type?(first_type) ->
        value

      first_type == :map ->
        Enum.map(value, &check_deep_struct/1)

      true ->
        safe_encode(value, :transform)
    end
  end

  defp check_deep_struct(value), do: safe_encode(value, :preserve)

  defp safe_encode(v, _) when is_binary(v), do: v

  defp safe_encode(v, :preserve) do
    case Jason.encode(v) do
      {:ok, _} -> v
      {:error, _} -> inspect(v)
    end
  end

  defp safe_encode(v, :transform) do
    case Jason.encode(v) do
      {:ok, encoded} -> encoded
      {:error, _} -> inspect(v)
    end
  end

  defp type(v) when is_map(v), do: :map
  defp type(v) when is_list(v), do: :list
  defp type(v) when is_integer(v), do: :integer
  defp type(v) when is_float(v), do: :float
  defp type(v) when is_number(v), do: :number
  defp type(v) when is_binary(v), do: :binary
  defp type(v) when is_boolean(v), do: :boolean
  defp type(_), do: :other

  defp is_primitive_type?(type) when type in [:binary, :integer, :float, :number, :boolean],
    do: true

  defp is_primitive_type?(_), do: false

  defp contains_nested_lists?(list) when is_list(list) do
    Enum.any?(list, &is_list/1)
  end
end
