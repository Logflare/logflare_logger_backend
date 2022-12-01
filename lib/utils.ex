defmodule LogflareLogger.Utils do
  @moduledoc false
  def default_metadata_keys do
    ~w[
      application
      module
      function
      file
      line
      pid
      crash_reason
      initial_call
      registered_name
      domain
      gl
      time
      mfa
    ]
  end

  def find_logflare_sys_envs() do
    envs = System.get_env()

    for {"LOGFLARE_" <> k, v} <- envs do
      k = String.downcase(k) |> String.to_atom()
      v = if k == :level, do: String.to_atom(v), else: v

      {k, v}
    end
  end
end
