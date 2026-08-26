defmodule PhxBackendBoilerplateWeb.Plugs.Authenticate do
  @moduledoc """
  Requires a valid access JWT in the `Authorization: Bearer` header.

  On success assigns `current_user_id` and `current_session_id`, and updates
  `RequestContext`. Rejects tokens whose session id appears in the Redis
  `expired_sessions` deny list.
  """

  import Plug.Conn

  alias PhxBackendBoilerplate.Accounts.ExpiredSessions
  alias PhxBackendBoilerplate.Accounts.Tokens
  alias PhxBackendBoilerplate.RequestContext

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, claims} <- Tokens.verify_access(token),
         false <- ExpiredSessions.revoked?(claims["jti"]) do
      conn
      |> assign(:current_user_id, claims["sub"])
      |> assign(:current_session_id, claims["jti"])
      |> tap(fn _ -> RequestContext.put_user_id(claims["sub"]) end)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{errors: %{detail: "Unauthorized"}})
        |> halt()
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 -> {:ok, token}
      _ -> :error
    end
  end
end
