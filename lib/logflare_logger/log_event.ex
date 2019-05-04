defmodule LogflareLogger.LogEvent do
  use TypedStruct

  typedstruct do
    field :level, atom, enforce: true
    field :message, String.t(), enforce: true
    field :context, map, default: %{}
    field :timestamp, non_neg_integer(), enforce: true
  end

  def new(timestamp, level, message, metadata \\ []) do
    context =
      %{}
      |> add_context(:metadata, metadata)
      |> add_context(:process)

    %__MODULE__{
      timestamp: timestamp,
      level: level,
      message: message,
      context: context
    }
    |> encode_timestamp()
  end

  defp add_context(context, :process) do
    Map.merge(context, LogflareLogger.context())
  end

  defp add_context(context, k = :metadata, metadata) do
    metadata =
      metadata
      |> encode_metadata()
      |> Map.take([
        :application,
        :module,
        :function,
        :file,
        :line,
        :pid,
        :crash_reason,
        :initial_call,
        :registered_name
      ])

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
