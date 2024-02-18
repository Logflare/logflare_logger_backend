defmodule LogflareLogger.BackendConfig do
  @moduledoc false
  @default_batch_size 100
  @default_flush_interval 5000

  alias LogflareLogger.Formatter

  use TypedStruct

  # TypeSpecs

  typedstruct do
    field :api_client, Tesla.Client.t()
    field :format, {atom, atom}, default: {Formatter, :format}
    field :level, atom, default: :info
    field :source_id, String.t()
    field :metadata, list(atom) | atom, default: :all
    field :toplevel, list(atom), default: []
    field :batch_max_size, non_neg_integer, default: @default_batch_size
    field :batch_size, non_neg_integer, default: 0
    field :flush_interval, non_neg_integer, default: @default_flush_interval
  end
end
