defmodule LogflareLogger do
  @moduledoc """
  """
  alias LogflareLogger.{BatchCache, Formatter}

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
    dt = NaiveDateTime.utc_now()
    {date, {hour, minute, second}} = NaiveDateTime.to_erl(dt)
    datetime = {date, {hour, minute, second, dt.microsecond}}
    config = :ets.lookup(:logflare_logger_table, :config) |> Keyword.get(:config)

    metadata =
      metadata
      |> Map.new()
      |> Map.merge(Map.new(Logger.metadata()))
      |> Map.merge(%{pid: self()})
      |> Enum.to_list()

    log_event = Formatter.format_event(level, message, datetime, metadata, config)
    BatchCache.put(log_event, config)
  end

  @doc """
  If no argument is provided, returns the LogflareLogger context stored in the process dictionary.
  """
  @spec context() :: map()
  def context() do
    Logger.metadata()
    |> Map.new()
  end

  @doc """
  If the argument is an atom, returns LogflareLogger context for the given key.
  If the argument is a map or keyword list, their keys/values are merged with the existing LogflareLogger context in the process dictionary. Setting the key to nil will remove that key from the context.
  """
  @spec context(map() | keyword()) :: map()
  def context(map) when is_map(map) do
    map
    |> Keyword.new()
    |> context()
  end

  def context(keyword) when is_list(keyword) do
    Logger.metadata(keyword)
    context()
  end

  @spec context(atom) :: map()
  def context(key) when is_atom(key) do
    context()
    |> Map.get(key)
  end

  @doc """
  If no argument is passed, resets the whole context from the process dictionary.
  If argument is an atom or a list of atoms, resets the context keeping only the given keys.
  """
  @spec reset_context() :: %{}
  def reset_context() do
    Logger.reset_metadata()
    context()
  end

  @spec reset_context([atom(), ...]) :: term
  def reset_context(keys) when is_list(keys) do
    Logger.reset_metadata(keys)
    context()
  end
end
