defmodule LogflareLogger.Formatter do
  @moduledoc false
  alias LogflareLogger.{LogParams, Utils}
  alias LogflareLogger.BackendConfig, as: Config

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

  def format_event(level, msg, ts, meta, %Config{metadata: :all}) do
    format(level, msg, ts, Map.new(meta))
  end

  def format_event(level, msg, ts, meta, %Config{metadata: metakeys}) when is_list(metakeys) do
    keys = Utils.default_metadata_keys() -- metakeys

    meta =
      meta
      |> Enum.into(%{})
      |> Map.drop(keys)

    format(level, msg, ts, meta)
  end
end
