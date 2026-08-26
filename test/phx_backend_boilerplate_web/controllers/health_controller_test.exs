defmodule PhxBackendBoilerplateWeb.HealthControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns 200 without authentication", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert json_response(conn, 200) == %{"status" => "ok"}
    end
  end

  describe "GET /ready" do
    test "returns 200 when dependencies are reachable", %{conn: conn} do
      conn = get(conn, ~p"/ready")

      assert json_response(conn, 200) == %{"status" => "ok"}
    end
  end
end
