defmodule PhxBackendBoilerplateWeb.Graphql.QueryTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  setup %{conn: conn} do
    conn =
      conn
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn}
  end

  test "ping returns pong", %{conn: conn} do
    conn =
      post(conn, ~p"/api/graphql", %{
        "query" => "{ ping }"
      })

    assert json_response(conn, 200) == %{"data" => %{"ping" => "pong"}}
  end

  test "hello greets by name", %{conn: conn} do
    conn =
      post(conn, ~p"/api/graphql", %{
        "query" => ~s|{ hello(name: "GraphQL") }|
      })

    assert json_response(conn, 200) == %{"data" => %{"hello" => "Hello, GraphQL!"}}
  end

  test "hello defaults to world", %{conn: conn} do
    conn =
      post(conn, ~p"/api/graphql", %{
        "query" => "{ hello }"
      })

    assert json_response(conn, 200) == %{"data" => %{"hello" => "Hello, world!"}}
  end

  test "malformed query returns GraphQL errors", %{conn: conn} do
    conn =
      post(conn, ~p"/api/graphql", %{
        "query" => "{ notARealField }"
      })

    assert %{"errors" => [%{"message" => message} | _]} = json_response(conn, 200)
    assert is_binary(message)
    refute Map.has_key?(json_response(conn, 200), "data")
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 2, rem(div(n, 256), 256), rem(n, 256)}
  end
end
