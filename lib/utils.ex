defmodule LogflareLogger.Utils do
  @moduledoc false
  def default_metadata_keys do
    [
      :application,
      :module,
      :function,
      :file,
      :line,
      :pid,
      :crash_reason,
      :initial_call,
      :registered_name
    ]
  end
end
