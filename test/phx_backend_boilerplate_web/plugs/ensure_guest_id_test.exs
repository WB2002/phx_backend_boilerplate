defmodule PhxBackendBoilerplateWeb.Plugs.EnsureGuestIdTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  alias PhxBackendBoilerplateWeb.Plugs.EnsureGuestId

  test "mints a guest id when header and cookie are absent" do
    conn = build_conn() |> EnsureGuestId.call([])

    guest_id = conn.assigns.guest_id
    assert is_binary(guest_id)
    assert byte_size(guest_id) > 0
    assert get_resp_header(conn, "x-guest-id") == [guest_id]
    assert conn.resp_cookies["guest_id"].value == guest_id
  end

  test "reuses x-guest-id header when present" do
    guest_id = Ecto.UUID.generate()

    conn =
      build_conn()
      |> put_req_header("x-guest-id", guest_id)
      |> EnsureGuestId.call([])

    assert conn.assigns.guest_id == guest_id
    assert get_resp_header(conn, "x-guest-id") == [guest_id]
  end

  test "reuses guest_id cookie when header is absent" do
    guest_id = Ecto.UUID.generate()

    conn =
      build_conn()
      |> put_req_cookie("guest_id", guest_id)
      |> EnsureGuestId.call([])

    assert conn.assigns.guest_id == guest_id
    assert get_resp_header(conn, "x-guest-id") == [guest_id]
  end
end
