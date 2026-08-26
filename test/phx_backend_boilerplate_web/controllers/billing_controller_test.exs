defmodule PhxBackendBoilerplateWeb.BillingControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Integrations.Stripe
  alias PhxBackendBoilerplate.Integrations.Stripe.Fake
  alias PhxBackendBoilerplate.Repo

  @register_attrs %{
    "email" => "billing@example.com",
    "password" => "password123"
  }

  setup %{conn: conn} do
    previous = Application.get_env(:phx_backend_boilerplate, Stripe, [])
    Fake.reset()

    Application.put_env(:phx_backend_boilerplate, Stripe,
      skip: false,
      adapter: Fake,
      secret_key: "sk_test_fake",
      webhook_secret: "whsec_test_fake"
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Stripe, previous)
    end)

    register_conn = Map.put(conn, :remote_ip, unique_ip())
    register_conn = post(register_conn, ~p"/api/auth/register", @register_attrs)
    access_token = json_response(register_conn, 201)["data"]["access_token"]
    user_id = json_response(register_conn, 201)["data"]["user"]["id"]

    {:ok,
     conn: build_conn() |> Map.put(:remote_ip, unique_ip()),
     access_token: access_token,
     user_id: user_id}
  end

  test "GET /api/billing/plans is public", %{conn: conn} do
    conn = get(conn, ~p"/api/billing/plans")

    assert %{"data" => plans} = json_response(conn, 200)
    assert length(plans) == 2
  end

  test "POST /api/billing/checkout-sessions requires auth", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/billing/checkout-sessions", %{"plan" => "lifetime"})

    assert json_response(conn, 401)["errors"]["detail"] == "Unauthorized"
  end

  test "POST /api/billing/checkout-sessions creates session", %{conn: conn, access_token: token} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/billing/checkout-sessions", %{"plan" => "lifetime"})

    assert %{
             "data" => %{
               "url" => url,
               "session_id" => session_id,
               "plan" => "lifetime",
               "mode" => "payment"
             }
           } = json_response(conn, 201)

    assert is_binary(url)
    assert is_binary(session_id)
  end

  test "POST /api/billing/checkout-sessions rejects invalid plan", %{
    conn: conn,
    access_token: token
  } do
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/billing/checkout-sessions", %{"plan" => "enterprise"})

    assert json_response(conn, 422)
  end

  test "GET /api/billing/me returns billing status", %{conn: conn, access_token: token} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/billing/me")

    assert %{"data" => %{"purchases" => [], "subscription" => nil}} = json_response(conn, 200)
  end

  test "GET /api/billing/me returns 401 when user was deleted but access token is still valid", %{
    conn: conn,
    access_token: token,
    user_id: user_id
  } do
    Repo.delete!(Accounts.get_user!(user_id))

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get(~p"/api/billing/me")

    assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
  end

  defp unique_ip do
    a = rem(System.unique_integer([:positive]), 200) + 1
    b = rem(System.unique_integer([:positive]), 200) + 1
    {127, 0, a, b}
  end
end
