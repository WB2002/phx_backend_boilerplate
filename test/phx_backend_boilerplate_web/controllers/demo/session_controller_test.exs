defmodule PhxBackendBoilerplateWeb.Demo.SessionControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplateWeb.SocketAuth

  @valid_creds %{
    "email" => "demo@example.com",
    "password" => "password123",
    "recaptcha_token" => "test-token"
  }
  @invalid_creds %{
    "email" => "demo@example.com",
    "password" => "wrong",
    "recaptcha_token" => "test-token"
  }

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

  test "rejects login when reCAPTCHA Fake fails", %{conn: conn} do
    previous =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake, [])

    Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake,
      result: {:error, :verification_failed}
    )

    on_exit(fn ->
      Application.put_env(
        :phx_backend_boilerplate,
        PhxBackendBoilerplate.Recaptcha.Fake,
        previous
      )
    end)

    conn =
      post(conn, ~p"/api/demo/login", Map.put(@valid_creds, "recaptcha_token", "bad-token"))

    assert json_response(conn, 403) == %{
             "errors" => %{"detail" => "reCAPTCHA verification failed"}
           }
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
