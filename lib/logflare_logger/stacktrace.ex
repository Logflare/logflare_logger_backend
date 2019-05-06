defmodule LogflareLogger.Stacktrace do
  @moduledoc """
  Handles stacktrace formatting for logged exceptions
  """

  def format(stacktrace) when is_list(stacktrace) do
    for i <- stacktrace, do: format_entry(i)
  end

  defp format_entry({mod, fun, args, location}) do
    %{
      module: field(:module, mod),
      file: field(:file, location),
      function: field(:function, fun),
      args_count: field(:args_count, args),
      line: field(:line, location)
    }
  end

end
