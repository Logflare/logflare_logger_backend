defmodule LogflareLogger.Formatter do
  alias LogflareLogger.LogEvent

  def format(level, message, ts, metadata) do
    try do
      LogEvent.new(ts, level, message, metadata)
      |> Map.from_struct()
    rescue
      e ->
        %{
          timestamp: Timex.to_unix(ts),
          level: "error",
          message:
            "Formatter encoding failed for message: #{inspect(message)} with error: #{inspect(e)}"
        }
    end
  end
end
