defmodule Mix.Tasks.LogflareLogger.VerifyConfig do
  use Mix.Task
  @app :logflare_logger
  @app_name "LogflareLogger"

  @impl Mix.Task
  def run(_args \\ []) do
    {:ok, _} = Application.ensure_all_started(:logflare_logger_backend)

    with {:api_key, true} <- {:api_key, api_key_set?()},
         {:source, true} <- {:source, source_set?()} do
      IO.puts("#{@app_name} configuration seems to be set correctly")
    else
      {:api_key, false} ->
        IO.puts("#{@app_name} API key not set")

      {:source, false} ->
        IO.puts("#{@app_name} Source not set")
    end
  end

  defp api_key_set? do
    :api_key
    |> get_env()
    |> is_not_nil()
  end

  defp source_set? do
    :source
    |> get_env()
    |> is_not_nil()
  end

  def get_env(key) do
    Application.get_env(@app, key)
  end

  def is_not_nil(arg) do
    !is_nil(arg)
  end
end
