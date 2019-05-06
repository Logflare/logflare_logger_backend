defmodule LogflareLogger.LogEvent do
  alias LogflareLogger.{Stacktrace, Utils}
  use TypedStruct
  @default_meta_keys Utils.default_metadata_keys()

  typedstruct do
    field :level, atom, enforce: true
    field :message, String.t(), enforce: true
    field :context, map, default: %{}
    field :timestamp, non_neg_integer(), enforce: true
  end

  def new(timestamp, level, message, metadata \\ []) do
    message_context =
      case metadata[:crash_reason] do
        {err, stacktrace} ->
          context =
            %{
              pid: metadata.pid,
              stacktrace: Stacktrace.format(stacktrace)
            }
            |> encode_metadata

          %{message: Exception.message(err), context: context}

        nil ->
          context =
            %{}
            |> add_context(:metadata, metadata)
            |> add_context(:process, metadata)

          %{message: message, context: context}
      end

    %__MODULE__{
      timestamp: timestamp,
      level: level,
      message: message_context.message,
      context: message_context.context
    }
    |> encode_timestamp()
  end

  defp add_context(context, :process, metadata) do
    Map.merge(context, Map.drop(metadata, @default_meta_keys))
  end

  defp add_context(context, k = :metadata, metadata) do
    metadata =
      metadata
      |> encode_metadata()
      |> Map.take(@default_meta_keys)

    Map.merge(context, %{k => metadata})
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
