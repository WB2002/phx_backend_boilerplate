defmodule PhxBackendBoilerplateWeb.Plugs.AuthenticateTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  import Plug.Conn

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Accounts.ExpiredSessions
  alias PhxBackendBoilerplateWeb.Plugs.Authenticate

  @attrs %{"email" => "plug@example.com", "password" => "password123"}

  setup do
    {:ok, auth} = Accounts.register(@attrs)
    {:ok, auth: auth}
  end

  test "allows a valid access token", %{conn: conn, auth: auth} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{auth.access_token}")
      |> Authenticate.call(Authenticate.init([]))

    refute conn.halted
    assert conn.assigns.current_user_id == auth.user.id
    assert conn.assigns.current_session_id == auth.session.id
  end

  test "rejects missing authorization header", %{conn: conn} do
    conn = Authenticate.call(conn, Authenticate.init([]))

    assert conn.halted
    assert conn.status == 401
  end

  test "rejects invalid token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer not-a-token")
      |> Authenticate.call(Authenticate.init([]))

    assert conn.halted
    assert conn.status == 401
  end

  test "rejects token whose session was revoked", %{conn: conn, auth: auth} do
    :ok = ExpiredSessions.revoke(auth.session.id)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{auth.access_token}")
      |> Authenticate.call(Authenticate.init([]))

    assert conn.halted
    assert conn.status == 401
  end
end
