defmodule LogflareLogger.LogEvent do
  alias LogflareLogger.{Stacktrace, Utils}
  use TypedStruct

  typedstruct do
    field :level, atom, enforce: true
    field :message, String.t(), enforce: true
    field :context, map, default: %{}
    field :timestamp, non_neg_integer(), enforce: true
  end

  def new(ts, lvl, msg, meta) when is_list(msg) do
    new(ts, lvl, message_to_string(msg), meta)
  end

  def new(ts, lvl, msg, meta) when is_tuple(ts) do
    ts = encode_timestamp(ts)
    new(ts, lvl, message_to_string(msg), meta)
  end

  def new(ts, lvl, msg, %{pid: pid} = meta) when is_pid(pid) do
    meta = Map.update!(meta, :pid, &pid_to_string/1)
    new(ts, lvl, message_to_string(msg), meta)
  end

  def new(ts, lvl, msg, %{crash_reason: cr} = meta) when not is_nil(cr) do
    {_err, stacktrace} = cr

    meta =
      meta
      |> Map.drop([:crash_reason])
      |> Map.merge(%{stacktrace: Stacktrace.format(stacktrace)})

    new(ts, lvl, message_to_string(msg), meta)
  end

  def new(timestamp, level, message, metadata) do
    {system_context, user_context} = Map.split(metadata, Utils.default_metadata_keys())

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

  def message_to_string(message) when is_binary(message), do: message

  def message_to_string(message) when is_list(message) do
    strings =
      for m <- message do
        if is_integer(m), do: to_string([m]), else: m
      end

    Enum.join(strings)
  end

  def pid_to_string(pid) when is_pid(pid) do
    pid
    |> :erlang.pid_to_list()
    |> to_string()
  end

  def prepare_logger_metadata(event), do: event

  def encode_timestamp(ts) do
    ts
    |> Timex.to_naive_datetime()
    |> Timex.to_datetime(Timex.Timezone.local())
    |> Timex.format!("{ISO:Extended}")
  end
end
