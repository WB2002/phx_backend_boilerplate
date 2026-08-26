defmodule PhxBackendBoilerplateWeb.Graphql.QueryTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  import PhxBackendBoilerplateWeb.GraphqlCase

  setup do
    {conn, _auth} = authenticated_graphql_conn()
    {:ok, conn: conn}
  end

  test "ping returns pong", %{conn: conn} do
    conn = graphql_post(conn, "{ ping }")

    assert json_response(conn, 200) == %{"data" => %{"ping" => "pong"}}
  end

  test "hello greets by name", %{conn: conn} do
    conn = graphql_post(conn, ~s|{ hello(name: "GraphQL") }|)

    assert json_response(conn, 200) == %{"data" => %{"hello" => "Hello, GraphQL!"}}
  end

  test "hello defaults to world", %{conn: conn} do
    conn = graphql_post(conn, "{ hello }")

    assert json_response(conn, 200) == %{"data" => %{"hello" => "Hello, world!"}}
  end

  test "malformed query returns GraphQL errors", %{conn: conn} do
    conn = graphql_post(conn, "{ notARealField }")

    assert %{"errors" => [%{"message" => message} | _]} = json_response(conn, 200)
    assert is_binary(message)
    refute Map.has_key?(json_response(conn, 200), "data")
  end

  test "returns 401 without authorization", %{conn: _conn} do
    conn =
      build_conn()
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("content-type", "application/json")
      |> graphql_post("{ ping }")

    assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
  end

  test "returns 401 when session is revoked", %{conn: _conn} do
    {conn, auth} = authenticated_graphql_conn()
    :ok = PhxBackendBoilerplate.Accounts.logout(auth.session.id)

    conn = graphql_post(conn, "{ ping }")

    assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
  end

  test "returns 413 when query exceeds byte limit", %{conn: conn} do
    max_bytes = PhxBackendBoilerplateWeb.Graphql.Config.max_query_bytes()
    conn = graphql_post(conn, oversized_query(max_bytes))

    assert json_response(conn, 413) == %{
             "errors" => %{
               "detail" => "GraphQL query exceeds maximum size of #{max_bytes} bytes"
             }
           }
  end

  test "returns error when complexity exceeds limit", %{conn: conn} do
    max = PhxBackendBoilerplateWeb.Graphql.Config.max_complexity()
    conn = graphql_post(conn, high_complexity_query(max + 1))

    assert %{"errors" => [%{"message" => message} | _]} = json_response(conn, 200)
    assert message =~ "complexity"
  end

  test "returns error when token count exceeds limit", %{conn: conn} do
    limit = PhxBackendBoilerplateWeb.Graphql.Config.token_limit()
    conn = graphql_post(conn, high_token_query(limit + 1))

    assert %{"errors" => [%{"message" => message} | _]} = json_response(conn, 200)
    assert message =~ ~r/token/i
  end

  test "returns error when selection depth exceeds limit", %{conn: conn} do
    max = PhxBackendBoilerplateWeb.Graphql.Config.max_depth()
    conn = graphql_post(conn, nested_depth_query(max + 1))

    assert %{"errors" => [%{"message" => message} | _]} = json_response(conn, 200)
    assert message =~ "depth"
  end
end
