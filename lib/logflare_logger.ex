defmodule LogflareLogger do
  @moduledoc """
  """
  alias LogflareLogger.{HttpBackend, BatchCache, Formatter}

  def debug(message, metadata \\ []) do
    log(:debug, message, metadata)
  end

  def info(message, metadata \\ []) do
    log(:info, message, metadata)
  end

  def warn(message, metadata \\ []) do
    log(:warn, message, metadata)
  end

  def error(message, metadata \\ []) do
    log(:error, message, metadata)
  end

  def log(level, message, metadata) do
    datetime = Timex.now() |> Timex.to_erl()
    config = BatchCache.get_config()

    metadata =
      metadata
      |> Enum.into(Map.new())
      |> Map.merge(Logger.metadata() |> Enum.into(Map.new()))
      |> Map.merge(%{pid: self()})
      |> Enum.into(Keyword.new())

    log_event = Formatter.format_event(level, message, datetime, metadata, config)
    BatchCache.put(log_event, config)
  end

  @doc """
  Merges map or keyword with the context in the process dictionary
  """
  @spec merge_context(map() | keyword()) :: map()
  def merge_context(map) when is_map(map) do
    map
    |> Keyword.new()
    |> merge_context()
  end

  def merge_context(keyword) when is_list(keyword) do
    Logger.metadata(keyword)
    get_context()
  end

  @doc """
  If key is passed, deletes context entry from the process dictionary. Otherwise deletes all context.
  """
  @spec delete_context() :: :ok
  def delete_context() do
    Logger.reset_metadata()
  end

  @spec delete_context(atom) :: :ok
  def delete_context(key) do
    Logger.metadata([{key, nil}])
  end

  @doc """
  Get context in the process dictionary.
  """
  @spec get_context() :: map()
  def get_context() do
    Logger.metadata()
    |> Map.new()
  end

  @spec get_context(atom) :: map()
  def get_context(key) do
    get_context()
    |> Map.get(key)
  end
end
