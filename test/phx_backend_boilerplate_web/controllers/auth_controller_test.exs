defmodule PhxBackendBoilerplateWeb.AuthControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Repo
  alias PhxBackendBoilerplateWeb.AuthCookies

  @register_attrs %{
    "email" => "auth@example.com",
    "password" => "password123"
  }

  setup %{conn: conn} do
    ip = unique_ip()
    {:ok, conn: Map.put(conn, :remote_ip, ip)}
  end

  describe "register" do
    test "creates a user and sets an httpOnly refresh cookie", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", @register_attrs)

      assert %{
               "data" => %{
                 "access_token" => access_token,
                 "expires_in" => 900,
                 "user" => %{"email" => "auth@example.com"}
               }
             } = json_response(conn, 201)

      assert is_binary(access_token)
      cookie = Map.fetch!(conn.resp_cookies, AuthCookies.cookie_name())
      assert cookie.http_only
      assert cookie.path == "/api/auth"
    end

    test "rejects passwords longer than 72 bytes", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/register", %{
          "email" => "longpass@example.com",
          "password" => String.duplicate("a", 73)
        })

      assert %{"errors" => %{"detail" => "Unprocessable Entity", "fields" => fields}} =
               json_response(conn, 422)

      assert fields["password"] == ["should be at most 72 character(s)"]
    end
  end

  describe "login" do
    setup do
      {:ok, _} = Accounts.register(@register_attrs)
      :ok
    end

    test "returns access token and refresh cookie", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => "auth@example.com",
          "password" => "password123"
        })

      assert %{"data" => %{"access_token" => access_token}} = json_response(conn, 200)
      assert is_binary(access_token)
      assert Map.has_key?(conn.resp_cookies, AuthCookies.cookie_name())
    end

    test "rejects invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => "auth@example.com",
          "password" => "wrong-password"
        })

      assert json_response(conn, 401) == %{
               "errors" => %{"detail" => "Invalid email or password"}
             }
    end

    test "rejects oversized passwords with the same error", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          "email" => "auth@example.com",
          "password" => String.duplicate("a", 73)
        })

      assert json_response(conn, 401) == %{
               "errors" => %{"detail" => "Invalid email or password"}
             }
    end
  end

  describe "authenticated flow" do
    setup %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", @register_attrs)
      access_token = json_response(conn, 201)["data"]["access_token"]
      user_id = json_response(conn, 201)["data"]["user"]["id"]
      refresh_cookie = Map.fetch!(conn.resp_cookies, AuthCookies.cookie_name())

      {:ok,
       conn: build_conn(),
       access_token: access_token,
       user_id: user_id,
       refresh_cookie: refresh_cookie,
       refresh_value: refresh_cookie.value}
    end

    test "GET /me returns the current user", %{conn: conn, access_token: access_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get(~p"/api/auth/me")

      assert %{"data" => %{"id" => id, "email" => "auth@example.com"}} = json_response(conn, 200)
      assert is_binary(id)
    end

    test "GET /me returns 401 without a token", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")
      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "GET /me returns 401 when user was deleted but access token is still valid", %{
      conn: conn,
      access_token: access_token,
      user_id: user_id
    } do
      Repo.delete!(Accounts.get_user!(user_id))

      me_conn =
        conn
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get(~p"/api/auth/me")

      assert json_response(me_conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "POST /refresh returns a new access token", %{
      conn: conn,
      refresh_cookie: refresh_cookie
    } do
      conn =
        conn
        |> put_req_cookie(AuthCookies.cookie_name(), refresh_cookie.value)
        |> post(~p"/api/auth/refresh")

      assert %{"data" => %{"access_token" => new_access}} = json_response(conn, 200)
      assert is_binary(new_access)
      assert Map.has_key?(conn.resp_cookies, AuthCookies.cookie_name())
    end

    test "POST /logout returns 401 without a token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/logout")
      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "POST /logout clears the session and cookie", %{
      conn: conn,
      access_token: access_token,
      refresh_value: refresh_value
    } do
      logout_conn =
        conn
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> put_req_cookie(AuthCookies.cookie_name(), refresh_value)
        |> post(~p"/api/auth/logout")

      assert logout_conn.status == 204

      me_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get(~p"/api/auth/me")

      assert json_response(me_conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 0, rem(div(n, 256), 256), rem(n, 256)}
  end
end
