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
          message: "Formatter error",
          context: %{
            formatter_error: inspect(e, safe: true),
            message_to_format: inspect(message, safe: true),
            metadata_to_format: inspect(metadata, safe: true),
          }
        }
    end
  end
end
