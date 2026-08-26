defmodule PhxBackendBoilerplateWeb.Graphql.MutationTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  setup %{conn: conn} do
    conn =
      conn
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("content-type", "application/json")

    {:ok, conn: conn}
  end

  test "echo returns id and message", %{conn: conn} do
    conn =
      post(conn, ~p"/api/graphql", %{
        "query" => ~s|mutation { echo(message: "hi") { id message } }|
      })

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
    conn =
      post(conn, ~p"/api/graphql", %{
        "query" => "mutation { echo { id message } }"
      })

    assert %{"errors" => errors} = json_response(conn, 200)
    assert is_list(errors)
    assert errors != []
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 3, rem(div(n, 256), 256), rem(n, 256)}
  end
end
