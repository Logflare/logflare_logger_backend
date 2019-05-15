defmodule LogflareLogger.TestUtils do
  def decode_logger_body(body) do
    body
    |> :zlib.gunzip()
    |> Bertex.safe_decode()
  end
end
