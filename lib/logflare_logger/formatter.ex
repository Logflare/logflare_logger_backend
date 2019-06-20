defmodule LogflareLogger.Formatter do
  @moduledoc false
  alias LogflareLogger.LogParams

  def format(level, message, ts, metadata) do
    try do
      LogParams.encode(ts, level, message, metadata)
    rescue
      e ->
        %{
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601(),
          level: "error",
          message: "LogflareLogger formatter error: #{inspect(e, safe: true)}",
          context: %{
            formatter: %{
              error: inspect(e, safe: true),
              message: inspect(message, safe: true),
              metadata: inspect(metadata, safe: true)
            }
          }
        }
    end
  end
end
