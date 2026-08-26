defmodule PhxBackendBoilerplateWeb.Demo.SessionControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplateWeb.SocketAuth

  @valid_creds %{"email" => "demo@example.com", "password" => "password123"}
  @invalid_creds %{"email" => "demo@example.com", "password" => "wrong"}

  setup %{conn: conn} do
    ip = unique_ip()
    {:ok, conn: Map.put(conn, :remote_ip, ip)}
  end

  test "logs in with valid demo credentials and a socket token", %{conn: conn} do
    conn = post(conn, ~p"/api/demo/login", @valid_creds)

    assert %{
             "data" => %{
               "message" => "Logged in",
               "email" => "demo@example.com",
               "user_id" => "demo-user",
               "socket_token" => socket_token
             }
           } = json_response(conn, 200)

    assert {:ok, %{"sub" => "demo-user", "email" => "demo@example.com"}} =
             SocketAuth.verify(socket_token)
  end

  test "rejects invalid credentials", %{conn: conn} do
    conn = post(conn, ~p"/api/demo/login", @invalid_creds)

    assert json_response(conn, 401) == %{
             "errors" => %{"detail" => "Invalid email or password"}
           }
  end

  test "returns 429 after exceeding the login rate limit", %{conn: conn} do
    for _ <- 1..5 do
      post(conn, ~p"/api/demo/login", @invalid_creds)
    end

    conn = post(conn, ~p"/api/demo/login", @invalid_creds)

    assert conn.status == 429
    assert get_resp_header(conn, "retry-after") != []
    assert Jason.decode!(conn.resp_body) == %{"errors" => %{"detail" => "Too Many Requests"}}
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 0, rem(div(n, 256), 256), rem(n, 256)}
  end
end
