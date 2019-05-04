defmodule LogflareLogger.LogEvent do
  use TypedStruct

  typedstruct do
    field :level, atom, enforce: true
    field :message, String.t(), enforce: true
    field :context, map, default: %{}
    field :timestamp, non_neg_integer(), enforce: true
  end

end
