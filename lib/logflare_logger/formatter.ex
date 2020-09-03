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
          "timestamp" => NaiveDateTime.to_iso8601(NaiveDateTime.utc_now(), :extended) <> "Z",
          "message" => "LogflareLogger formatter error: #{inspect(e, safe: true)}",
          "metadata" => %{
            "log_params_with_errors" => %{
              "metadata" =>
                inspect(metadata, safe: true, limit: :infinity, printable_limit: :infinity),
              "timestamp" => inspect(ts),
              "message" => inspect(message),
              "level" => inspect(level)
            },
            "level" => "error"
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

  def format_event(_, _, _, _, nil) do
    raise("LogflareLogger is not configured!")
  end
end
