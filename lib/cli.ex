defmodule LogflareLogger.CLI do

  def throw_on_missing_url!(url) do
    unless url do
      throw("Logflare API url #{not_configured()}")
    end
  end

  def throw_on_missing_source!(source_id) do
    unless source_id do
      throw("Logflare source_id #{not_configured()}")
    end
  end

  def throw_on_missing_api_key!(api_key) do
    unless api_key do
      throw("Logflare API key #{not_configured()}")
    end
  end

  def not_configured() do
    "for LogflareLogger backend is NOT configured"
  end

end
