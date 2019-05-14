defmodule LogflareLogger.LogEvent do
  alias LogflareLogger.{Stacktrace, Utils}
  use TypedStruct

  typedstruct do
    field :level, atom, enforce: true
    field :message, String.t(), enforce: true
    field :metadata, map, default: %{}
    field :timestamp, non_neg_integer(), enforce: true
  end

  def new(timestamp, level, message, metadata \\ %{}) do
    message = message_to_string(message)

    logflare_metadata =
      case metadata[:crash_reason] do
        {_err, stacktrace} ->
          logflare_metadata =
            %{}
            |> add_context(:context, %{
              pid: metadata.pid,
              stacktrace: Stacktrace.format(stacktrace)
            })
            |> encode_metadata

          logflare_metadata

        nil ->
          logflare_metadata =
            %{}
            |> add_context(:context, metadata)
            |> add_context(:process, metadata)

          logflare_metadata
      end

    %__MODULE__{
      timestamp: timestamp,
      level: level,
      message: message,
      metadata: logflare_metadata
    }
    |> encode_timestamp()
  end

  def message_to_string(message) when is_binary(message), do: message

  def message_to_string(message) when is_list(message) do
    strings =
      for m <- message do
        if is_integer(m) do
          to_string([m])
        else
          m
        end
      end

    Enum.join(strings)
  end

  defp add_context(logflare_metadata, :process, metadata) do
    process = metadata |> Map.drop(Utils.default_metadata_keys())
    Map.merge(logflare_metadata, process)
  end

  defp add_context(logflare_metadata, k = :context, metadata) do
    metadata =
      metadata
      |> encode_metadata()
      |> Map.take(Utils.default_metadata_keys() ++ [:stacktrace])

    Map.merge(logflare_metadata, %{k => metadata})
  end

  def encode_metadata(%{pid: pid} = metadata) when is_pid(pid) do
    metadata.pid
    |> update_in(&to_string(:erlang.pid_to_list(&1)))
    |> encode_metadata()
  end

  def encode_metadata(event), do: event

  def encode_timestamp(event) do
    update_in(
      event.timestamp,
      fn ts ->
        ts
        |> Timex.to_naive_datetime()
        |> Timex.to_datetime(Timex.Timezone.local())
        |> Timex.format!("{ISO:Extended}")
      end
    )
  end
end
