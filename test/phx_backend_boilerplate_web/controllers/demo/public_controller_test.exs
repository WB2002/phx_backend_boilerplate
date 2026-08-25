defmodule PhxBackendBoilerplateWeb.Demo.PublicControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  setup %{conn: conn} do
    ip = unique_ip()
    guest_id = Ecto.UUID.generate()

    conn =
      conn
      |> Map.put(:remote_ip, ip)
      |> put_req_header("x-guest-id", guest_id)

    {:ok, conn: conn, guest_id: guest_id}
  end

  test "returns public demo payload with guest_id", %{conn: conn, guest_id: guest_id} do
    conn = get(conn, ~p"/api/demo/public")

    assert %{
             "data" => %{
               "message" => "Public demo",
               "guest_id" => ^guest_id
             }
           } = json_response(conn, 200)

    assert get_resp_header(conn, "x-guest-id") == [guest_id]
  end

  test "returns 429 after exceeding the public rate limit", %{conn: conn} do
    for _ <- 1..5 do
      get(conn, ~p"/api/demo/public")
    end

    conn = get(conn, ~p"/api/demo/public")

    assert conn.status == 429
    assert get_resp_header(conn, "retry-after") != []
    assert Jason.decode!(conn.resp_body) == %{"errors" => %{"detail" => "Too Many Requests"}}
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 1, rem(div(n, 256), 256), rem(n, 256)}
  end
end
