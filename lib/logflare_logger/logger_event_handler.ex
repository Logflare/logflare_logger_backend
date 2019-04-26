defmodule LogflareLogger.Backend do
  @moduledoc """
  Implements :gen_event behaviour, handles incoming Logger messages
  """
  @behaviour :gen_event

  def init({__MODULE__, options}) do
    {:ok, configure(options, [])}
  end

  def handle_event({_level, gl, {Logger, _, _, _}}, state)
      when node(gl) != node() do
    {:ok, state}
  end

  def handle_event(:flush, state), do: {:ok, state}

  def handle_call({:configure, options}, state) do
    {:ok, :ok, configure(options, state)}
  end

  def handle_info(_, state), do: {:ok, state}

  def code_change(_old_vsn, state, _extra), do: {:ok, state}

  def terminate(_reason, _state), do: :ok

  defp configure(options, _state), do: options
end
