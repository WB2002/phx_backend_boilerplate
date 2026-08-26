defmodule PhxBackendBoilerplateWeb.Plugs.GraphqlContext do
  @moduledoc """
  Passes authenticated user identity into Absinthe via `Absinthe.Plug.put_options/2`.

  Requires `Authenticate` to have assigned `current_user_id` and `current_session_id`.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    Absinthe.Plug.put_options(conn,
      context: %{
        current_user_id: conn.assigns.current_user_id,
        current_session_id: conn.assigns.current_session_id
      }
    )
  end
end
