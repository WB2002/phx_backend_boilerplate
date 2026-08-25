defmodule PhxBackendBoilerplateWeb.Demo.ExpensiveControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  setup %{conn: conn} do
    ip = unique_ip()
    {:ok, conn: Map.put(conn, :remote_ip, ip)}
  end

  test "returns expensive demo payload", %{conn: conn} do
    conn = get(conn, ~p"/api/demo/expensive")

    assert %{
             "data" => %{
               "message" => "Expensive demo",
               "hold_ms" => 0
             }
           } = json_response(conn, 200)
  end

  test "caps hold_ms and echoes it", %{conn: conn} do
    conn = get(conn, ~p"/api/demo/expensive?hold_ms=50")

    assert %{"data" => %{"hold_ms" => 50}} = json_response(conn, 200)
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 2, rem(div(n, 256), 256), rem(n, 256)}
  end
end
