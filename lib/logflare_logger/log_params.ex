defmodule LogflareLogger.LogParams do
  @moduledoc """
  Parses and encodes incoming Logger messages for further serialization.
  """
  alias LogflareLogger.{Stacktrace, Utils}
  @default_metadata_keys Utils.default_metadata_keys()

  @doc """
  Creates a LogParams struct when all fields have serializable values
  """
  def encode(timestamp, level, message, metadata) do
    new(timestamp, level, message, metadata)
  end

  def new(timestamp, level, message, metadata) do
    message = encode_message(message)
    timestamp = encode_timestamp(timestamp)
    metadata = encode_metadata(metadata)

    {stacktrace, metadata} = Map.pop(metadata, "stacktrace")

    {system_context, user_context} = Map.split(metadata, @default_metadata_keys)

    system_context =
      system_context
      |> enrich(:vm)

    log_params = %{
      "timestamp" => timestamp,
      "message" => message,
      "metadata" =>
        user_context
        |> Map.put("level", Atom.to_string(level))
        |> Map.put("context", system_context)
    }

    if stacktrace do
      put_in(log_params, ~w[metadata stacktrace], stacktrace)
    else
      log_params
    end
  end

  def enrich(context, :vm) do
    Map.merge(context, %{"vm" => %{"node" => "#{Node.self()}"}})
  end

  @doc """
  Encodes message, if is iodata converts to binary.
  """
  def encode_message(message) do
    to_string(message)
  end

  @doc """
  Converts erlang datetime tuple into ISO:Extended binary.
  """
  def encode_timestamp(t) when is_tuple(t) do
    t
    |> Timex.to_datetime(Timex.Timezone.local())
    |> Timex.format!("{ISO:Extended}")
  end

  def encode_metadata(meta) do
    meta
    |> encode_crash_reason()
    |> traverse_convert()
  end

  @doc """
  Adds formatted stacktrace to the metadata
  """
  def encode_crash_reason(%{crash_reason: cr} = meta) when not is_nil(cr) do
    {_err, stacktrace} = cr

    meta
    |> Map.drop([:crash_reason])
    |> Map.merge(%{stacktrace: Stacktrace.format(stacktrace)})
  end

  def encode_crash_reason(meta), do: meta

  def traverse_convert(%NaiveDateTime{} = v), do: to_string(v)
  def traverse_convert(%DateTime{} = v), do: to_string(v)

  def traverse_convert(%{__struct__: _} = v) do
    v |> Map.from_struct() |> traverse_convert()
  end

  def traverse_convert(data) when is_map(data) do
    for {k, v} <- data, into: Map.new() do
      {traverse_convert(k), traverse_convert(v)}
    end
  end

  def traverse_convert(xs) when is_list(xs) do
    cond do
      Keyword.keyword?(xs) ->
        xs
        |> Enum.into(Map.new())
        |> traverse_convert()

      length(xs) > 0 and List.ascii_printable?(xs) ->
        to_string(xs)

      true ->
        for x <- xs, do: traverse_convert(x)
    end
  end

  def traverse_convert(x) when is_tuple(x) do
    x |> Tuple.to_list() |> traverse_convert()
  end

  @doc """
  All atoms are converted to strings for Logflare server to be able
  to safely convert binary to terms using :erlang.binary_to_term(binary, [:safe])
  """
  def traverse_convert(x) when is_boolean(x), do: x

  def traverse_convert(nil), do: nil

  def traverse_convert(x) when is_atom(x), do: Atom.to_string(x)

  def traverse_convert(x) when is_pid(x) do
    x
    |> :erlang.pid_to_list()
    |> to_string()
  end

  def traverse_convert(x), do: x
end
