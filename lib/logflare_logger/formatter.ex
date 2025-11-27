defmodule LogflareLogger.Formatter do
  @moduledoc false

  require Logger

  alias LogflareLogger.LogParams
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
            "formatter_error_params" => %{
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

  def format_event(level, msg, ts, meta, %Config{metadata: [drop: dropkeys]})
      when is_list(dropkeys) do
    meta =
      meta
      |> Enum.into(%{})
      |> Map.drop(dropkeys)

    format(level, msg, ts, meta)
  end

  def format_event(level, msg, ts, meta, %Config{metadata: metakeys}) when is_list(metakeys) do
    Logger.warning(
      "Your logflare_logger_backend configuration key `metadata` is deprecated. Looks like you're using a list of keywords. Please use `metadata: :all` or `metadata: [drop: [:keys, :to, :drop]]`"
    )

    format(level, msg, ts, Map.new(meta))
  end

  def format_event(_, _, _, _, nil) do
    raise("LogflareLogger is not configured!")
  end
end
