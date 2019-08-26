defmodule LogflareLogger.Stacktrace do
  @moduledoc """
  Handles stacktrace formatting for logged exceptions
  """

  def format(stacktrace) when is_list(stacktrace) do
    for i <- stacktrace, do: i |> format_entry()
  end

  defp format_entry({mod, fun, arity_or_args, location} = entry) do
    %{
      module: format_field(:module, mod),
      file: format_field(:file, location),
      line: format_field(:line, location),
      function: format_field(:function, fun, arity_or_args),
      arity: format_field(:arity, arity_or_args),
      args: format_field(:args, arity_or_args)
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

  defp format_field(:file, location) do
    case Keyword.get(location, :file) do
      nil -> nil
      x -> to_string(x)
    end
  end

  defp format_field(:line, location) do
    case Keyword.get(location, :line) do
      nil -> nil
      int when is_integer(int) -> int
      _ -> nil
    end
  end

  defp format_field(:function, fun, args) do
    arity = format_field(:arity, args)

    if arity do
      "#{fun}/#{arity}"
    else
      "#{fun}"
    end
  end

  defp format_field(:arity, arity) when is_integer(arity), do: arity
  defp format_field(:arity, _), do: nil

  defp format_field(:args, args) when is_list(args), do: inspect(args)
  defp format_field(:args, _), do: nil
end
