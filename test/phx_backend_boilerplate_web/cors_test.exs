defmodule PhxBackendBoilerplateWeb.CORSTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: true

  test "preflight OPTIONS echoes allowlisted Origin" do
    conn =
      build_conn()
      |> put_req_header("origin", "http://localhost:3000")
      |> put_req_header("access-control-request-method", "GET")
      |> put_req_header("access-control-request-headers", "content-type,x-guest-id")
      |> Phoenix.ConnTest.dispatch(@endpoint, :options, "/api/demo/public")

    assert conn.status == 204
    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
    assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]

    allow_headers =
      conn
      |> get_resp_header("access-control-allow-headers")
      |> List.first()
      |> String.downcase()

    assert allow_headers =~ "x-guest-id"
    assert allow_headers =~ "content-type"
  end

  test "disallowed Origin does not receive allow-origin" do
    conn =
      build_conn()
      |> put_req_header("origin", "https://evil.example")
      |> get(~p"/api/demo/public")

    assert get_resp_header(conn, "access-control-allow-origin") == []
  end

  test "allowlisted Origin on GET receives CORS headers" do
    conn =
      build_conn()
      |> put_req_header("origin", "http://localhost:3000")
      |> get(~p"/api/demo/public")

    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
    assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
  end
end
