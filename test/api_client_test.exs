defmodule LogflareLogger.ApiClientTest do
  use ExUnit.Case
  alias LogflareLogger.ApiClient
  alias LogflareLogger.TestUtils
  require Logger

  @port 4444
  @path ApiClient.api_path()

  @api_key "l3kh47jsakf2370dasg"
  @source_id "source2354551"

  setup do
    bypass = Bypass.open(port: @port)

    {:ok, bypass: bypass}
  end

  test "ApiClient sends a correct POST request with gzip in bert format", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", @path, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert {"x-api-key", @api_key} in conn.req_headers

      body = TestUtils.decode_logger_body(body)

      assert %{
               "batch" => [
                 %{
                   "level" => "info",
                   "message" => "Logger message",
                   "metadata" => %{
                     "context" => %{
                       "file" => "not_existing.ex"
                     }
                   }
                 }
               ],
               "source" => @source_id
             } = body

      Plug.Conn.resp(conn, 200, "ok")
    end)

    client = ApiClient.new(%{api_key: @api_key, url: "http://localhost:#{@port}"})

    batch = [
      %{
        "level" => "info",
        "message" => "Logger message",
        "context" => %{
          "system" => %{
            "file" => "not_existing.ex"
          }
        }
      }
    ]

    {:ok, %{body: body}} = ApiClient.post_logs(client, batch, @source_id)

    assert body == "ok"
  end
end
