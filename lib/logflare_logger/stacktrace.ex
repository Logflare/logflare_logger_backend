defmodule LogflareLogger.Stacktrace do
  @moduledoc """
  Handles stacktrace formatting for logged exceptions
  """

  def format(stacktrace) when is_list(stacktrace) do
    for i <- stacktrace, do: format_entry(i)
  end

  defp format_entry({mod, fun, arity_or_args, location} = entry) do
    %{
      module: format_field(:module, mod),
      file: format_field(:file, location),
      line: format_field(:line, location),
      function: format_field(:function, fun, arity_or_args),
      arity_or_args: format_field(:arity_or_args, arity_or_args)
    }
  end

  defp format_field(_, ""), do: nil
  defp format_field(_, nil), do: nil

  defp format_field(field, term) when is_atom(term) do
    format_field(field, to_string(term))
  end

  defp format_field(:module, mod) when is_binary(mod) do
    String.replace_prefix(mod, "Elixir.", "")
  end

  defp format_field(field, []) when field in [:file, :line] do
    nil
  end

  defp format_field(:file, location), do: Keyword.get(location, :file) |> to_string
  defp format_field(:line, location), do: Keyword.get(location, :line)

  defp format_field(:function, fun, args) do
    arity = format_field(:arity_or_args, args)
    "#{fun}/#{arity}"
  end

  defp format_field(:arity_or_args, arity) when is_integer(arity) do
    arity
  end

  defp format_field(:arity_or_args, args) do
    args
  end
end
