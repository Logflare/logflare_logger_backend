defmodule LogflareLogger.Formatter do
  @moduledoc false

  require Logger

  alias LogflareLogger.LogParams
  alias LogflareLogger.BackendConfig, as: Config

  @metadata_deprecation_warned_key {__MODULE__, :metadata_deprecation_warned}

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
    warn_metadata_deprecated_once(metakeys)

    format(level, msg, ts, Map.new(meta))
  end

  def format_event(_, _, _, _, nil) do
    raise("LogflareLogger is not configured!")
  end

  # Guards against an infinite loop: Logger.warning/1 re-enters this backend
  # as a new event, which would otherwise re-trigger the same warning.
  defp warn_metadata_deprecated_once(metakeys) do
    key = {@metadata_deprecation_warned_key, metakeys}

    if :persistent_term.get(key, false) == false do
      :persistent_term.put(key, true)

      Logger.warning(
        "Your logflare_logger_backend configuration key `metadata` is deprecated. Looks like you're using a list of keywords. Please use `metadata: :all` or `metadata: [drop: [:keys, :to, :drop]]`"
      )
    end
  end
end
