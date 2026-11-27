defmodule PhxBackendBoilerplateWeb.OpenAPIControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  describe "GET /openapi.json" do
    test "returns a valid OpenAPI 3.0.3 document when enabled", %{conn: conn} do
      original = Application.get_env(:phx_backend_boilerplate, :openapi)

      on_exit(fn ->
        if original == nil do
          Application.delete_env(:phx_backend_boilerplate, :openapi)
        else
          Application.put_env(:phx_backend_boilerplate, :openapi, original)
        end
      end)

      Application.put_env(:phx_backend_boilerplate, :openapi, enabled: true)

      conn = get(conn, ~p"/openapi.json")
      body = json_response(conn, 200)

      assert body["openapi"] == "3.0.3"
      assert is_map(body["info"])
      assert is_map(body["paths"]["/health"])
      assert is_map(body["paths"]["/api/auth/login"])
      assert is_map(body["paths"]["/api/auth/me"])
      assert is_map(body["components"]["securitySchemes"]["bearerAuth"])
    end

    test "returns 404 when disabled", %{conn: conn} do
      original = Application.get_env(:phx_backend_boilerplate, :openapi)

      on_exit(fn ->
        if original == nil do
          Application.delete_env(:phx_backend_boilerplate, :openapi)
        else
          Application.put_env(:phx_backend_boilerplate, :openapi, original)
        end
      end)

      Application.put_env(:phx_backend_boilerplate, :openapi, enabled: false)

      conn = get(conn, ~p"/openapi.json")
      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
