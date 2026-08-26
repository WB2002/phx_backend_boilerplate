defmodule PhxBackendBoilerplateWeb.AuthController do
  @moduledoc """
  Email/password registration, login, refresh, logout, and current-user endpoints.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplateWeb.AuthCookies

  action_fallback PhxBackendBoilerplateWeb.FallbackController

  @invalid_credentials_detail "Invalid email or password"

  def register(conn, params) do
    case Accounts.register(params) do
      {:ok, auth} ->
        conn
        |> put_refresh_cookie(auth)
        |> put_status(:created)
        |> json(%{data: auth_payload(auth)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.login(email, password) do
      {:ok, auth} ->
        conn
        |> put_refresh_cookie(auth)
        |> json(%{data: auth_payload(auth)})

      {:error, :invalid_credentials} ->
        unauthorized(conn, @invalid_credentials_detail)
    end
  end

  def login(conn, _params) do
    unauthorized(conn, @invalid_credentials_detail)
  end

  def refresh(conn, _params) do
    case AuthCookies.get_refresh(conn) do
      refresh_token when is_binary(refresh_token) ->
        case Accounts.refresh(refresh_token) do
          {:ok, auth} ->
            conn
            |> put_refresh_cookie(auth)
            |> json(%{data: auth_payload(auth)})

          {:error, _} ->
            unauthorized(conn, "Invalid or expired refresh token")
        end

      _ ->
        unauthorized(conn, "Invalid or expired refresh token")
    end
  end

  def logout(conn, _params) do
    session_id = resolve_session_id(conn)

    if session_id do
      Accounts.logout(session_id)
    end

    conn
    |> AuthCookies.delete_refresh()
    |> send_resp(:no_content, "")
  end

  def me(conn, _params) do
    case Accounts.get_user(conn.assigns.current_user_id) do
      nil ->
        unauthorized(conn, "Unauthorized")

      user ->
        json(conn, %{
          data: %{
            id: user.id,
            email: user.email
          }
        })
    end
  end

  defp auth_payload(auth) do
    %{
      access_token: auth.access_token,
      expires_in: auth.expires_in,
      user: %{
        id: auth.user.id,
        email: auth.user.email
      }
    }
  end

  defp put_refresh_cookie(conn, auth) do
    AuthCookies.put_refresh(conn, auth.refresh_token, auth.session.expires_at)
  end

  defp resolve_session_id(conn) do
    cond do
      session_id = session_id_from_bearer(conn) ->
        session_id

      refresh_token = AuthCookies.get_refresh(conn) ->
        case Accounts.session_id_from_token(refresh_token, :refresh) do
          {:ok, session_id} -> session_id
          _ -> nil
        end

      true ->
        nil
    end
  end

  defp session_id_from_bearer(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, session_id} <- Accounts.session_id_from_token(token, :access) do
      session_id
    else
      _ -> nil
    end
  end

  defp unauthorized(conn, detail) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: detail}})
  end
end
