defmodule PhxBackendBoilerplateWeb.UserSocketTest do
  use PhxBackendBoilerplateWeb.ChannelCase, async: true

  alias PhxBackendBoilerplateWeb.SocketAuth
  alias PhxBackendBoilerplateWeb.SocketLimits
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

  test "rejects oversized connect tokens" do
    token = String.duplicate("a", SocketLimits.max_token_bytes() + 1)
    assert :error = connect(UserSocket, %{"token" => token})
  end

  test "rejects connects when peer IP exceeds rate limit" do
    token = SocketAuth.sign(@claims)
    peer = %{address: {203, 0, 113, 50}, port: 44_000, ssl_cert: nil}
    max = SocketLimits.max_connects_per_minute()

    for _ <- 1..max do
      assert {:ok, _socket} =
               connect(UserSocket, %{"token" => token}, connect_info: %{peer_data: peer})
    end

    assert :error =
             connect(UserSocket, %{"token" => token}, connect_info: %{peer_data: peer})
  end
end
