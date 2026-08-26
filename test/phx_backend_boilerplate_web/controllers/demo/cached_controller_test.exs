defmodule PhxBackendBoilerplateWeb.Demo.CachedControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplate.Cache.L1
  alias PhxBackendBoilerplate.Cache.L2

  setup %{conn: conn} do
    ip = unique_ip()
    key = "demo-cached-#{:erlang.unique_integer([:positive])}"
    _ = L1.delete(key)
    _ = L2.delete(key)
    _ = L2.delete("swr:lock:#{key}")
    {:ok, conn: Map.put(conn, :remote_ip, ip), key: key}
  end

  test "returns cached payload with freshness", %{conn: conn, key: key} do
    conn = get(conn, ~p"/api/demo/cached?key=#{key}&work_ms=0")

    assert %{
             "data" => %{"key" => ^key, "work_ms" => 0},
             "freshness" => "miss"
           } = json_response(conn, 200)
  end

  test "echoes request_id and correlation_id response headers", %{conn: conn, key: key} do
    conn =
      conn
      |> put_req_header("x-correlation-id", "journey-cached-1")
      |> get(~p"/api/demo/cached?key=#{key}&work_ms=0")

    assert json_response(conn, 200)
    assert [request_id] = get_resp_header(conn, "x-request-id")
    assert request_id != ""
    assert get_resp_header(conn, "x-correlation-id") == ["journey-cached-1"]
  end

  test "caps work_ms at 2000", %{conn: conn, key: key} do
    conn = get(conn, ~p"/api/demo/cached?key=#{key}&work_ms=99999")

    assert %{"data" => %{"work_ms" => 2000}, "freshness" => "miss"} = json_response(conn, 200)
  end

  test "returns generic 500 without leaking internal error details", %{conn: conn, key: key} do
    conn = get(conn, ~p"/api/demo/cached?key=#{key}&error=1")

    assert %{"errors" => %{"detail" => "Internal Server Error"}} = json_response(conn, 500)
    refute conn.resp_body =~ "econnrefused"
    refute conn.resp_body =~ "l2"
  end

  test "parallel requests coalesce on cold key", %{key: key} do
    tasks =
      for _ <- 1..8 do
        Task.async(fn ->
          build_conn()
          |> Map.put(:remote_ip, unique_ip())
          |> get(~p"/api/demo/cached?key=#{key}&work_ms=100")
          |> json_response(200)
        end)
      end

    bodies = Task.await_many(tasks, 5_000)
    computed = Enum.map(bodies, &get_in(&1, ["data", "computed_at"]))

    assert length(Enum.uniq(computed)) == 1
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 3, rem(div(n, 256), 256), rem(n, 256)}
  end
end
