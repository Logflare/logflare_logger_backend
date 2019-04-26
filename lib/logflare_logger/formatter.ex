defmodule LogflareLogger.Formatter do
  alias Jason, as: JSON

  def format(level, message, ts, metadata) do
    structured = %{
      timestamp: Timex.to_unix(ts),
      level: level,
      message: message,
      metadata: []
    }

    try do
      JSON.encode!(structured)
    rescue
      _ ->
        %{
          timestamp: Timex.to_unix(ts),
          level: "error",
          message: "Formatter encoding failed for message: #{message}"
        }
    end
  end
end
