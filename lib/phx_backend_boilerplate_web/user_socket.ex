defmodule PhxBackendBoilerplateWeb.UserSocket do
  @moduledoc """
  Authenticated websocket entrypoint.

  Clients must pass a `token` connect param signed by
  `PhxBackendBoilerplateWeb.SocketAuth` (minted on demo login).
  """

  use Phoenix.Socket

  channel "demo:*", PhxBackendBoilerplateWeb.DemoChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) when is_binary(token) do
    if byte_size(token) > PhxBackendBoilerplateWeb.SocketLimits.max_token_bytes() do
      :error
    else
      case PhxBackendBoilerplateWeb.SocketAuth.verify(token) do
        {:ok, %{"sub" => user_id, "email" => email}} ->
          socket =
            socket
            |> assign(:current_user_id, user_id)
            |> assign(:email, email)

          {:ok, socket}

        {:error, _reason} ->
          :error
      end
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user_id}"
end
