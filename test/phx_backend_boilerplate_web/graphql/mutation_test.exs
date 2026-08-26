defmodule PhxBackendBoilerplateWeb.Graphql.MutationTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  import PhxBackendBoilerplateWeb.GraphqlCase

  setup do
    {conn, _auth} = authenticated_graphql_conn()
    {:ok, conn: conn}
  end

  test "echo returns id and message", %{conn: conn} do
    conn = graphql_post(conn, ~s|mutation { echo(message: "hi") { id message } }|)

    assert %{
             "data" => %{
               "echo" => %{
                 "id" => id,
                 "message" => "hi"
               }
             }
           } = json_response(conn, 200)

    assert is_binary(id)
    assert byte_size(id) > 0
  end

  test "echo without message returns validation errors", %{conn: conn} do
    conn = graphql_post(conn, "mutation { echo { id message } }")

    assert %{"errors" => errors} = json_response(conn, 200)
    assert is_list(errors)
    assert errors != []
  end

  test "returns 401 without authorization", %{conn: _conn} do
    conn =
      build_conn()
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("content-type", "application/json")
      |> graphql_post(~s|mutation { echo(message: "hi") { id message } }|)

    assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
  end
end
