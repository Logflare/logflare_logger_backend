defmodule LogflareLogger do
  @moduledoc """
  """

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
