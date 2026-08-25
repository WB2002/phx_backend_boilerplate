defmodule PhxBackendBoilerplateWeb.Plugs.EnsureGuestId do
  @moduledoc """
  Ensures a stable guest identity for public API requests.

  Resolution order:

    1. `x-guest-id` request header
    2. `guest_id` cookie
    3. Mint a new UUID

  Always assigns `conn.assigns.guest_id`, sets the `guest_id` cookie
  (HttpOnly, SameSite=Lax), and echoes `x-guest-id` on the response.

  Wire this only on **public** pipelines — authenticated routes should
  rate-limit by `user_id` instead.
  """

  import Plug.Conn

  @behaviour Plug

  @cookie_name "guest_id"
  @header_name "x-guest-id"
  @cookie_max_age 60 * 60 * 24 * 365

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn = fetch_cookies(conn)
    guest_id = resolve_guest_id(conn)

    conn
    |> assign(:guest_id, guest_id)
    |> put_resp_header(@header_name, guest_id)
    |> put_resp_cookie(@cookie_name, guest_id,
      http_only: true,
      same_site: "Lax",
      path: "/",
      max_age: @cookie_max_age
    )
  end

  defp resolve_guest_id(conn) do
    header_id = conn |> get_req_header(@header_name) |> List.first()
    cookie_id = conn.cookies[@cookie_name]

    cond do
      present?(header_id) -> header_id
      present?(cookie_id) -> cookie_id
      true -> Ecto.UUID.generate()
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false
end
