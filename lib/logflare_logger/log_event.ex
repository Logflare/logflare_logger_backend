defmodule LogflareLogger.LogEvent do
  alias LogflareLogger.{Stacktrace, Utils}
  use TypedStruct
  @default_meta_keys Utils.default_metadata_keys()

  typedstruct do
    field :level, atom, enforce: true
    field :message, String.t(), enforce: true
    field :metadata, map, default: %{}
    field :timestamp, non_neg_integer(), enforce: true
  end

  def new(timestamp, level, message, metadata \\ []) do
    {message, logflare_metadata} =
      case metadata[:crash_reason] do
        {err, stacktrace} ->
          logflare_metadata =
            %{}
            |> add_context(:context, %{
              pid: metadata.pid,
              stacktrace: Stacktrace.format(stacktrace)
            })
            |> add_context(:process, metadata)
            |> encode_metadata

          {Exception.message(err), logflare_metadata}

        nil ->
          logflare_metadata =
            %{}
            |> add_context(:context, metadata)
            |> add_context(:process, metadata)

          {message, logflare_metadata}
      end

    %__MODULE__{
      timestamp: timestamp,
      level: level,
      message: message,
      metadata: logflare_metadata
    }
    |> encode_timestamp()
  end

  defp add_context(logflare_metadata, :process, metadata) do
    Map.merge(logflare_metadata, Map.drop(metadata, @default_meta_keys))
  end

  defp add_context(logflare_metadata, k = :context, metadata) do
    metadata = encode_metadata(metadata)

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
