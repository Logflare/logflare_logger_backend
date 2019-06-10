defmodule LogflareLogger.LogEvent do
  @moduledoc """
  Parses and encodes incoming Logger messages for further serialization.
  """
  alias LogflareLogger.{Stacktrace, Utils}
  @default_metadata_keys Utils.default_metadata_keys()

  use TypedStruct

  typedstruct do
    field :level, atom, enforce: true
    field :message, String.t(), enforce: true
    field :context, map, default: %{}
    field :timestamp, non_neg_integer(), enforce: true
  end

  @doc """
  Converts iodata message into binary.
  """
  def new(ts, lvl, msg, meta) when is_list(msg) do
    new(ts, lvl, message_to_string(msg), meta)
  end

  @doc """
  Converts erlang datetime tuple into ISO:Extended binary.
  """
  def new(ts, lvl, msg, meta) when is_tuple(ts) do
    ts = encode_timestamp(ts)
    new(ts, lvl, msg, meta)
  end

  @doc """
  Converts pid to string
  """
  def new(ts, lvl, msg, %{pid: pid} = meta) when is_pid(pid) do
    new(ts, lvl, msg, %{meta | pid: pid_to_string(pid)})
  end

  @doc """
  Adds formatted stacktrace to the metadata
  """
  def new(ts, lvl, msg, %{crash_reason: cr} = meta) when not is_nil(cr) do
    {_err, stacktrace} = cr

    meta =
      meta
      |> Map.drop([:crash_reason])
      |> Map.merge(%{stacktrace: Stacktrace.format(stacktrace)})

    new(ts, lvl, msg, meta)
  end

  @doc """
  Creates a LogEvent struct when all fields have serializable values
  """
  def new(timestamp, level, message, metadata)
      when is_binary(timestamp) and
             is_binary(message) and
             is_atom(level) and
             is_map(metadata) do
    {system_context, user_context} =
      metadata
      |> encode_metadata_charlists()
      |> Map.split(@default_metadata_keys)

    %__MODULE__{
      timestamp: timestamp,
      level: level,
      message: message,
      context: %{
        system: system_context,
        user: user_context
      }
    }
  end

  def encode_metadata_charlists(metadata) do
    for {k, v} <- metadata, into: Map.new() do
      v =
        cond do
          is_map(v) -> encode_metadata_charlists(v)
          is_list(v) and List.ascii_printable?(v) -> to_string(v)
          true -> v
        end

      {k, v}
    end
  end

  defp message_to_string(message) when is_binary(message), do: message

  defp message_to_string(message) when is_list(message) do
    strings =
      for m <- message do
        if is_integer(m), do: to_string([m]), else: m
      end

    Enum.join(strings)
  end

  defp pid_to_string(pid) when is_pid(pid) do
    pid
    |> :erlang.pid_to_list()
    |> to_string()
  end

  defp encode_timestamp(ts) do
    ts
    |> Timex.to_naive_datetime()
    |> Timex.to_datetime(Timex.Timezone.local())
    |> Timex.format!("{ISO:Extended}")
  end
end
