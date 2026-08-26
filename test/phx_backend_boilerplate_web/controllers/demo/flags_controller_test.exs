defmodule PhxBackendBoilerplateWeb.Demo.FlagsControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplate.Flags

  setup %{conn: conn} do
    _ = FunWithFlags.clear(:demo_preview)
    _ = FunWithFlags.clear(:demo_beta)

    ip = unique_ip()
    guest_id = Ecto.UUID.generate()

    conn =
      conn
      |> Map.put(:remote_ip, ip)
      |> put_req_header("x-guest-id", guest_id)

    {:ok, conn: conn, guest_id: guest_id}
  end

  describe "GET /api/demo/flags/preview" do
    test "returns 404 when :demo_preview is disabled", %{conn: conn} do
      conn = get(conn, ~p"/api/demo/flags/preview")

      assert conn.status == 404
      assert Jason.decode!(conn.resp_body) == %{"errors" => %{"detail" => "Not Found"}}
    end

    test "returns 200 when :demo_preview is enabled", %{conn: conn} do
      assert {:ok, true} = FunWithFlags.enable(:demo_preview)

      conn = get(conn, ~p"/api/demo/flags/preview")

      assert %{
               "data" => %{
                 "feature" => "preview",
                 "enabled" => true
               }
             } = json_response(conn, 200)
    end
  end

  describe "GET /api/demo/flags/beta" do
    test "returns 403 when :demo_beta is not enabled for guest", %{conn: conn} do
      conn = get(conn, ~p"/api/demo/flags/beta")

      assert conn.status == 403
      assert Jason.decode!(conn.resp_body) == %{"errors" => %{"detail" => "Forbidden"}}
    end

    test "returns 200 when :demo_beta is enabled for guest", %{conn: conn, guest_id: guest_id} do
      assert {:ok, true} = FunWithFlags.enable(:demo_beta, for_actor: Flags.guest(guest_id))

      conn = get(conn, ~p"/api/demo/flags/beta")

      assert %{
               "data" => %{
                 "feature" => "beta",
                 "guest_id" => ^guest_id,
                 "enabled" => true
               }
             } = json_response(conn, 200)
    end
  end

  defp unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 4, rem(div(n, 256), 256), rem(n, 256)}
  end
end
