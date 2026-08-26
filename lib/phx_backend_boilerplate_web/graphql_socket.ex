defmodule PhxBackendBoilerplateWeb.GraphqlSocket do
  @moduledoc """
  Public Absinthe WebSocket for GraphQL subscriptions.

  Separate from `UserSocket`, which requires a signed demo login token.
  """

  use Phoenix.Socket

  use Absinthe.Phoenix.Socket,
    schema: PhxBackendBoilerplateWeb.Graphql.Schema

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
