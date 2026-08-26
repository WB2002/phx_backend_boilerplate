defmodule PhxBackendBoilerplateWeb.Plugs.SecurityHeadersTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: true

  alias PhxBackendBoilerplateWeb.Plugs.SecurityHeaders

  @api_csp "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
  @dev_csp "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self' ws: wss:; frame-ancestors 'none'"

  test "sets strict CSP and companion headers for API paths" do
    conn =
      build_conn(:get, "/api/demo/public")
      |> SecurityHeaders.call([])

    assert get_resp_header(conn, "content-security-policy") == [@api_csp]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(conn, "x-frame-options") == ["DENY"]
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]

    assert get_resp_header(conn, "permissions-policy") == [
             "camera=(), microphone=(), geolocation=()"
           ]
  end

  test "sets looser CSP for /dev paths" do
    conn =
      build_conn(:get, "/dev/dashboard")
      |> SecurityHeaders.call([])

    assert get_resp_header(conn, "content-security-policy") == [@dev_csp]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
  end

  test "API responses from the endpoint include security headers" do
    conn = get(build_conn(), ~p"/api/demo/public")

    assert get_resp_header(conn, "content-security-policy") == [@api_csp]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
  end
end
