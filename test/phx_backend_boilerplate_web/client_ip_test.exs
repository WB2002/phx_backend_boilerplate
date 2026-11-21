defmodule PhxBackendBoilerplateWeb.ClientIpTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: true

  alias PhxBackendBoilerplateWeb.ClientIp

  test "uses remote_ip when X-Forwarded-For trust is disabled" do
    conn =
      build_conn()
      |> Map.put(:remote_ip, {203, 0, 113, 10})
      |> put_req_header("x-forwarded-for", "198.51.100.1")

    assert ClientIp.from_conn(conn) == "203.0.113.10"
  end

  test "uses rightmost untrusted X-Forwarded-For hop when trust is enabled" do
    previous = Application.get_env(:phx_backend_boilerplate, ClientIp, [])

    Application.put_env(
      :phx_backend_boilerplate,
      ClientIp,
      Keyword.merge(previous, trust_x_forwarded_for: true, trusted_proxy_cidrs: [])
    )

    on_exit(fn -> Application.put_env(:phx_backend_boilerplate, ClientIp, previous) end)

    conn =
      build_conn()
      |> Map.put(:remote_ip, {10, 0, 0, 1})
      |> put_req_header("x-forwarded-for", "203.0.113.25, 10.0.0.1")

    assert ClientIp.from_conn(conn) == "203.0.113.25"
  end

  test "ignores spoofed leftmost hop when trust is enabled" do
    previous = Application.get_env(:phx_backend_boilerplate, ClientIp, [])

    Application.put_env(
      :phx_backend_boilerplate,
      ClientIp,
      Keyword.merge(previous, trust_x_forwarded_for: true, trusted_proxy_cidrs: [])
    )

    on_exit(fn -> Application.put_env(:phx_backend_boilerplate, ClientIp, previous) end)

    conn =
      build_conn()
      |> Map.put(:remote_ip, {10, 0, 0, 1})
      |> put_req_header("x-forwarded-for", "198.51.100.99, 203.0.113.25, 10.0.0.1")

    assert ClientIp.from_conn(conn) == "203.0.113.25"
  end

  test "falls back to remote_ip when X-Forwarded-For has no trusted proxy suffix" do
    previous = Application.get_env(:phx_backend_boilerplate, ClientIp, [])

    Application.put_env(
      :phx_backend_boilerplate,
      ClientIp,
      Keyword.put(previous, :trust_x_forwarded_for, true)
    )

    on_exit(fn -> Application.put_env(:phx_backend_boilerplate, ClientIp, previous) end)

    conn =
      build_conn()
      |> Map.put(:remote_ip, {10, 0, 0, 1})
      |> put_req_header("x-forwarded-for", "203.0.113.50")

    assert ClientIp.from_conn(conn) == "10.0.0.1"
  end

  test "from_connect_info uses peer_data when X-Forwarded-For trust is disabled" do
    connect_info = %{
      peer_data: %{address: {203, 0, 113, 10}},
      x_headers: [{"x-forwarded-for", "198.51.100.1"}]
    }

    assert ClientIp.from_connect_info(connect_info) == "203.0.113.10"
  end

  test "from_connect_info uses rightmost untrusted hop when trust is enabled" do
    previous = Application.get_env(:phx_backend_boilerplate, ClientIp, [])

    Application.put_env(
      :phx_backend_boilerplate,
      ClientIp,
      Keyword.put(previous, :trust_x_forwarded_for, true)
    )

    on_exit(fn -> Application.put_env(:phx_backend_boilerplate, ClientIp, previous) end)

    connect_info = %{
      peer_data: %{address: {10, 0, 0, 1}},
      x_headers: [{"x-forwarded-for", "198.51.100.1, 10.0.0.1"}]
    }

    assert ClientIp.from_connect_info(connect_info) == "198.51.100.1"
  end
end
