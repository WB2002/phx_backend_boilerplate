defmodule PhxBackendBoilerplateWeb.AuthCookies do
  @moduledoc """
  HttpOnly refresh-token cookie helpers for `/api/auth` routes.
  """

  import Plug.Conn

  @cookie_name "_phx_backend_boilerplate_refresh"
  @path "/api/auth"

  @doc false
  def cookie_name, do: @cookie_name

  @doc """
  Sets the refresh JWT cookie with `max_age` derived from the session deadline.
  """
  @spec put_refresh(Plug.Conn.t(), String.t(), DateTime.t()) :: Plug.Conn.t()
  def put_refresh(conn, refresh_token, %DateTime{} = expires_at) do
    max_age =
      expires_at
      |> DateTime.diff(DateTime.utc_now(:second), :second)
      |> max(0)

    put_resp_cookie(conn, @cookie_name, refresh_token, cookie_opts(max_age))
  end

  @doc """
  Clears the refresh cookie.
  """
  @spec delete_refresh(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_refresh(conn) do
    delete_resp_cookie(
      conn,
      @cookie_name,
      Keyword.take(cookie_opts(0), [:path, :secure, :same_site])
    )
  end

  @doc """
  Reads the refresh token from the request cookie, if present.
  """
  @spec get_refresh(Plug.Conn.t()) :: String.t() | nil
  def get_refresh(conn) do
    conn = fetch_cookies(conn)
    conn.cookies[@cookie_name]
  end

  defp cookie_opts(max_age) do
    [
      http_only: true,
      same_site: "Lax",
      path: @path,
      max_age: max_age,
      secure: secure?()
    ]
  end

  @doc """
  Whether auth and guest cookies should include the `Secure` flag.

  Driven by `config :phx_backend_boilerplate, PhxBackendBoilerplateWeb.AuthCookies, secure: ...`
  (enabled in production via `config/runtime.exs`).
  """
  @spec secure?() :: boolean()
  def secure? do
    Application.get_env(
      :phx_backend_boilerplate,
      PhxBackendBoilerplateWeb.AuthCookies,
      []
    )
    |> Keyword.get(:secure, false)
  end
end
