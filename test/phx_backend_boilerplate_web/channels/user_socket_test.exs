defmodule PhxBackendBoilerplateWeb.UserSocketTest do
  use PhxBackendBoilerplateWeb.ChannelCase, async: true

  alias PhxBackendBoilerplateWeb.SocketAuth
  alias PhxBackendBoilerplateWeb.UserSocket

  @claims %{"sub" => "demo-user", "email" => "demo@example.com"}

  test "connects with a valid token" do
    token = SocketAuth.sign(@claims)

    assert {:ok, socket} = connect(UserSocket, %{"token" => token})
    assert socket.assigns.current_user_id == "demo-user"
    assert socket.assigns.email == "demo@example.com"
    assert UserSocket.id(socket) == "user_socket:demo-user"
  end

  test "rejects missing token" do
    assert :error = connect(UserSocket, %{})
  end

  test "rejects invalid token" do
    assert :error = connect(UserSocket, %{"token" => "bogus"})
  end
end
