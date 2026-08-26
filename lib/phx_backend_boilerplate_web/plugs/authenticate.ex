defmodule PhxBackendBoilerplateWeb.Plugs.Authenticate do
  @moduledoc """
  Requires a valid access JWT in the `Authorization: Bearer` header.

  On success assigns `current_user_id` and `current_session_id`, and updates
  `RequestContext`. Rejects tokens when `Accounts.authenticate_access_token/1`
  reports the session revoked (Redis deny list, with Postgres fallback when the
  cache is unavailable).
  """

  import Plug.Conn

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.RequestContext

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with {:ok, token} <- bearer_token(conn),
         {:ok, %{user_id: user_id, session_id: session_id}} <-
           Accounts.authenticate_access_token(token) do
      conn
      |> assign(:current_user_id, user_id)
      |> assign(:current_session_id, session_id)
      |> tap(fn _ -> RequestContext.put_user_id(user_id) end)
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
