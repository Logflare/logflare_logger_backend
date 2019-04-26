defmodule LogflareLogger.Backend do
  @moduledoc """
  Implements :gen_event behaviour, handles incoming Logger messages
  """
  @behaviour :gen_event
  alias LogflareLogger.ApiClient

  def init({__MODULE__, options}) do
    {:ok, configure(options, [])}
  end

  def handle_event({_level, gl, _msg}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({_level, gl, {Logger, msg, datetime, metadata}}, state) do
    {:ok, _} = ApiClient.post_logs(state.api_client, msg)
    {:ok, state}
  end

  def handle_event(:flush, state), do: {:ok, state}

  def handle_call({:configure, options}, state) do
    {:ok, :ok, configure(options, state)}
  end

  def handle_info(_, state), do: {:ok, state}

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(_reason, _state), do: :ok

  defp configure(options, _state) when is_list(options) do
    port = Keyword.get(options, :port)
    host = Keyword.get(options, :host)
    api_client = ApiClient.new(%{port: port, host: host})
    %{api_client: api_client}
  end

  defp configure(:test, _state) do
    %{}
  end
end
