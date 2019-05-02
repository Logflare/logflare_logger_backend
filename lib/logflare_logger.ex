defmodule LogflareLogger do
  @moduledoc """
  """

  @doc """
  Adds log entry context to the current process
  """
  @spec set_context(map() | keyword()) :: map()
  def set_context(map) when is_map(map) do
    set_context(Keyword.new(map))
  end

  def set_context(keyword) do
    Logger.metadata(keyword)
    context()
  end

  @doc """
  Deletes a key from context saved in the current process.

  The second parameter indicates which context you want the key to be removed from.
  """
  @spec unset_context() :: :ok
  def unset_context() do
    Logger.reset_metadata()
  end

  @spec unset_context(atom) :: :ok
  def unset_context(key) do
    Logger.metadata([{key, nil}])
  end

  @doc """
  Gets the current context
  """
  @spec context() :: Context.t()
  def context() do
    case Logger.metadata() do
      [] ->
        %{}

      meta ->
        meta
        |> Map.new()
    end
  end
end
