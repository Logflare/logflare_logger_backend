defmodule LogflareLogger.Repo do
  use Ecto.Repo, otp_app: :logflare_logger_backend, adapter: Etso.Adapter
end
