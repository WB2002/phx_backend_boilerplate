defmodule PhxBackendBoilerplateWeb.Plugs.EnsureGuestId do
  @moduledoc """
  Ensures a stable guest identity for public API requests.

  Resolution order:

    1. `guest_id` cookie (server-issued; cannot be overridden by header)
    2. `x-guest-id` request header (bootstrap for cookieless first visits)
    3. Mint a new UUID

  Always assigns `conn.assigns.guest_id`, sets the `guest_id` cookie
  (HttpOnly, SameSite=Lax, Secure in production), and echoes `x-guest-id`
  on the response.

  Wire this only on **public** pipelines — authenticated routes should
  rate-limit by `user_id` instead.
  """

  import Plug.Conn

  alias PhxBackendBoilerplateWeb.AuthCookies

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
      secure: AuthCookies.secure?(),
      path: "/",
      max_age: @cookie_max_age
    )
  end

  defp resolve_guest_id(conn) do
    cookie_id = conn.cookies[@cookie_name]
    header_id = conn |> get_req_header(@header_name) |> List.first()

    cond do
      valid_uuid?(cookie_id) -> cookie_id
      valid_uuid?(header_id) -> header_id
      true -> Ecto.UUID.generate()
    end
  end

  defp valid_uuid?(value) when is_binary(value) do
    case Ecto.UUID.cast(String.trim(value)) do
      {:ok, uuid} -> is_binary(uuid)
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false
end
