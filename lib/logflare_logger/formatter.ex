defmodule LogflareLogger.Formatter do
  def format(level, message, ts, metadata) do
    event = %{
      timestamp: Timex.to_unix(ts),
      level: level,
      message: message,
      metadata: metadata
    }

    try do
      event
      |> metadata_to_binary()
    rescue
      e ->
        %{
          timestamp: Timex.to_unix(ts),
          level: "error",
          message: "Formatter encoding failed for message: #{inspect message} with error: #{inspect(e)}"
        }
    end
  end

  def metadata_to_binary(%{metadata: %{pid: pid}} = event) when is_pid(pid) do
    event.metadata.pid
    |> update_in(&to_string(:erlang.pid_to_list(&1)))
    |> metadata_to_binary()
  end

  def metadata_to_binary(event), do: event
end
