defmodule PhxBackendBoilerplate.Integration.StackIntegrationTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  @moduletag :integration

  alias PhxBackendBoilerplate.RateLimit
  alias PhxBackendBoilerplate.Repo

  test "postgres and redis backing services are reachable" do
    assert %{rows: [[1]]} = Repo.query!("SELECT 1")

    bucket_key = "integration_check:#{System.unique_integer([:positive])}"
    assert {:allow, 1} = RateLimit.hit(bucket_key, :timer.minutes(1), 10)
  end

  test "probe endpoints succeed through the full HTTP stack", %{conn: conn} do
    health_conn = get(conn, ~p"/health")
    assert json_response(health_conn, 200) == %{"status" => "ok"}

    ready_conn = get(build_conn(), ~p"/ready")
    assert json_response(ready_conn, 200) == %{"status" => "ok"}
  end

  test "full auth lifecycle integrates with GraphQL and session revocation" do
    unique_suffix = System.unique_integer([:positive])
    email = "integration-#{unique_suffix}@example.com"
    password = "StrongPassword123!"
    remote_ip = {127, 0, rem(unique_suffix, 200) + 1, 1}

    register_conn =
      build_conn()
      |> Map.put(:remote_ip, remote_ip)
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/auth/register", %{email: email, password: password})

    register_body = json_response(register_conn, 201)
    assert get_in(register_body, ["data", "user", "email"]) == email

    login_conn =
      build_conn()
      |> Map.put(:remote_ip, remote_ip)
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/auth/login", %{email: email, password: password})

    login_body = json_response(login_conn, 200)
    access_token = get_in(login_body, ["data", "access_token"])
    assert is_binary(access_token) and byte_size(access_token) > 20

    me_conn =
      build_conn()
      |> Map.put(:remote_ip, remote_ip)
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> get(~p"/api/auth/me")

    assert get_in(json_response(me_conn, 200), ["data", "email"]) == email

    gql_conn =
      build_conn()
      |> Map.put(:remote_ip, remote_ip)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> post(~p"/api/graphql", %{query: ~s|{ ping hello(name: "Integration") }|})

    assert json_response(gql_conn, 200) == %{
             "data" => %{
               "ping" => "pong",
               "hello" => "Hello, Integration!"
             }
           }

    logout_conn =
      build_conn()
      |> Map.put(:remote_ip, remote_ip)
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> post(~p"/api/auth/logout")

    assert response(logout_conn, 204)

    revoked_gql_conn =
      build_conn()
      |> Map.put(:remote_ip, remote_ip)
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{access_token}")
      |> post(~p"/api/graphql", %{query: "{ ping }"})

    assert json_response(revoked_gql_conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
  end
end
