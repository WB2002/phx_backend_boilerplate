defmodule PhxBackendBoilerplateWeb.DemoChannelTest do
  use PhxBackendBoilerplateWeb.ChannelCase, async: true

  alias PhxBackendBoilerplate.PubSub
  alias PhxBackendBoilerplateWeb.SocketAuth
  alias PhxBackendBoilerplateWeb.UserSocket

  @claims %{"sub" => "demo-user", "email" => "demo@example.com"}

  setup do
    token = SocketAuth.sign(@claims)
    {:ok, socket} = connect(UserSocket, %{"token" => token})
    {:ok, socket: socket}
  end

  test "joins demo:lobby", %{socket: socket} do
    assert {:ok, _reply, _socket} = subscribe_and_join(socket, "demo:lobby", %{})
  end

  test "joins own user topic", %{socket: socket} do
    assert {:ok, _reply, _socket} = subscribe_and_join(socket, "demo:user:demo-user", %{})
  end

  test "rejects another user's topic", %{socket: socket} do
    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(socket, "demo:user:someone-else", %{})
  end

  test "rejects unknown demo topics", %{socket: socket} do
    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(socket, "demo:secret", %{})
  end

  test "replies to ping", %{socket: socket} do
    {:ok, _, socket} = subscribe_and_join(socket, "demo:lobby", %{})

    ref = push(socket, "ping", %{"hello" => "world"})
    assert_reply ref, :ok, %{"hello" => "world"}
  end

  test "pushes PubSub broadcasts as client events", %{socket: socket} do
    {:ok, _, _socket} = subscribe_and_join(socket, "demo:lobby", %{})

    payload = %{"event" => "comment_created", "title" => "Hi"}
    assert :ok = PubSub.broadcast("demo:lobby", payload)

    assert_push "comment_created", ^payload
  end

  test "defaults push event to msg when payload has no event key", %{socket: socket} do
    {:ok, _, _socket} = subscribe_and_join(socket, "demo:lobby", %{})

    payload = %{"title" => "no event"}
    assert :ok = PubSub.broadcast("demo:lobby", payload)

    assert_push "msg", ^payload
  end
end
