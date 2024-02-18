defmodule LogflareLogger.Formatter do
  @moduledoc false

  require Logger

  alias LogflareLogger.LogParams
  alias LogflareLogger.BackendConfig, as: Config

  defp format(root, level, message, ts, metadata) do
    root = for {k, v} <- root, into: %{}, do: {Atom.to_string(k), v}

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
    |> Map.merge(root)
  end

  def format_event(level, msg, ts, meta, %Config{} = config) do
    meta = Map.new(meta)
    {root, meta} = extract_root(meta, config.toplevel)
    meta = filter_metadata(meta, config.metadata)

    format(root, level, msg, ts, meta)
  end

  def format_event(_, _, _, _, nil) do
    raise("LogflareLogger is not configured!")
  end

  defp filter_metadata(meta, :all), do: meta
  defp filter_metadata(meta, drop: keys), do: Map.drop(meta, keys)

  defp filter_metadata(meta, metakeys) when is_list(metakeys) do
    IO.warn(
      "Your logflare_logger_backend configuration key `metadata` is deprecated. Looks like you're using a list of keywords. Please use `metadata: :all` or `metadata: [drop: [:keys, :to, :drop]]`"
    )

    meta
  end

  defp extract_root(meta, keys), do: Map.split(meta, keys)
end
