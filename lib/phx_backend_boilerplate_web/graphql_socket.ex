defmodule PhxBackendBoilerplateWeb.GraphqlSocket do
  @moduledoc """
  Authenticated Absinthe WebSocket for GraphQL subscriptions.

  Clients must pass an access JWT as the `token` connect param (same token as
  `Authorization: Bearer` on HTTP). GraphiQL (dev-only) accepts the token in
  connection params for subscription testing.

  Separate from `UserSocket`, which uses a signed demo login Phoenix.Token.
  """

  use Phoenix.Socket

  use Absinthe.Phoenix.Socket,
    schema: PhxBackendBoilerplateWeb.Graphql.Schema,
    pipeline: {PhxBackendBoilerplateWeb.Graphql.Pipeline, :for_socket}

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplateWeb.Graphql.Config
  alias PhxBackendBoilerplateWeb.SocketLimits

  @impl true
  def connect(%{"token" => token}, socket, connect_info) when is_binary(token) do
    with :ok <- SocketLimits.rate_limit_connect(connect_info),
         true <- byte_size(token) <= SocketLimits.max_token_bytes() do
      authenticate_socket(token, socket)
    else
      _ -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  defp authenticate_socket(token, socket) do
    case Accounts.authenticate_access_token(token) do
      {:ok, %{user_id: user_id, session_id: session_id}} ->
        socket =
          socket
          |> assign(:current_user_id, user_id)
          |> assign(:current_session_id, session_id)
          |> Absinthe.Phoenix.Socket.put_options(
            Keyword.merge(
              Config.absinthe_options(),
              context: %{
                current_user_id: user_id,
                current_session_id: session_id
              }
            )
          )

        {:ok, socket}

      {:error, :unauthorized} ->
        :error
    end
  end

  @impl true
  def id(%{assigns: %{current_user_id: user_id, current_session_id: session_id}}),
    do: "graphql_socket:#{user_id}:#{session_id}"
end
