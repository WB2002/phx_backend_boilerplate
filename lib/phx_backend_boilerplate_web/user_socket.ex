defmodule PhxBackendBoilerplateWeb.UserSocket do
  @moduledoc """
  Authenticated websocket entrypoint.

  Clients must pass a `token` connect param signed by
  `PhxBackendBoilerplateWeb.SocketAuth` (minted on demo login).
  """

  use Phoenix.Socket

  alias PhxBackendBoilerplateWeb.SocketLimits

  channel "demo:*", PhxBackendBoilerplateWeb.DemoChannel

  @impl true
  def connect(%{"token" => token}, socket, connect_info) when is_binary(token) do
    with :ok <- SocketLimits.rate_limit_connect(connect_info),
         true <- byte_size(token) <= SocketLimits.max_token_bytes(),
         {:ok, %{"sub" => user_id, "email" => email}} <-
           PhxBackendBoilerplateWeb.SocketAuth.verify(token) do
      socket =
        socket
        |> assign(:current_user_id, user_id)
        |> assign(:email, email)

      {:ok, socket}
    else
      _ -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user_id}"
end
