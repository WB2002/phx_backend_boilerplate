defmodule PhxBackendBoilerplateWeb.Plugs.GraphqlBodyLimitTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: true

  alias PhxBackendBoilerplateWeb.Plugs.GraphqlBodyLimit

  setup do
    opts = GraphqlBodyLimit.init([])
    %{opts: opts}
  end

  test "matches graphql path_info including trailing slash segment", %{opts: opts} do
    max_query = PhxBackendBoilerplateWeb.Graphql.Config.max_query_bytes()
    over = max_query + 4_096 + 1

    conn =
      build_conn()
      |> Map.put(:path_info, ["api", "graphql", ""])
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("content-length", Integer.to_string(over))

    conn = GraphqlBodyLimit.call(conn, opts)

    assert conn.halted
    assert conn.status == 413
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {127, 0, rem(div(n, 256), 256), rem(n, 256)}
  end
end
