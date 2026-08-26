defmodule PhxBackendBoilerplateWeb.Graphql.SubscriptionTest do
  use PhxBackendBoilerplateWeb.ChannelCase, async: false
  use Absinthe.Phoenix.SubscriptionTest, schema: PhxBackendBoilerplateWeb.Graphql.Schema

  import PhxBackendBoilerplateWeb.GraphqlCase

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplateWeb.GraphqlSocket

  setup do
    {:ok, auth} = Accounts.register(unique_user_attrs())
    {:ok, socket} = connect(GraphqlSocket, %{"token" => auth.access_token})
    {:ok, socket} = join_absinthe(socket)

    {:ok, socket: socket, auth: auth}
  end

  test "echoed subscription receives published echo", %{socket: socket} do
    sub_ref =
      push_doc(socket, """
      subscription {
        echoed {
          id
          message
        }
      }
      """)

    assert_reply sub_ref, :ok, %{subscriptionId: subscription_id}

    mut_ref =
      push_doc(socket, """
      mutation {
        echo(message: "hi") {
          id
          message
        }
      }
      """)

    assert_reply mut_ref, :ok, %{
      data: %{"echo" => %{"id" => id, "message" => "hi"}}
    }

    assert_push "subscription:data", %{
      result: %{data: %{"echoed" => %{"id" => ^id, "message" => "hi"}}},
      subscriptionId: ^subscription_id
    }
  end

  test "rejects connect without token" do
    assert :error = connect(GraphqlSocket, %{})
  end

  test "rejects connect with invalid token" do
    assert :error = connect(GraphqlSocket, %{"token" => "not-a-jwt"})
  end

  test "rejects connect when session is revoked", %{auth: auth} do
    :ok = Accounts.logout(auth.session.id)
    assert :error = connect(GraphqlSocket, %{"token" => auth.access_token})
  end

  test "echoed events are isolated per user" do
    {:ok, auth_a} = Accounts.register(unique_user_attrs())
    {:ok, auth_b} = Accounts.register(unique_user_attrs())

    {:ok, socket_a} = connect(GraphqlSocket, %{"token" => auth_a.access_token})
    {:ok, socket_a} = join_absinthe(socket_a)

    {:ok, socket_b} = connect(GraphqlSocket, %{"token" => auth_b.access_token})
    {:ok, socket_b} = join_absinthe(socket_b)

    sub_a =
      push_doc(socket_a, """
      subscription { echoed { id message } }
      """)

    assert_reply sub_a, :ok, %{subscriptionId: _}

    sub_b =
      push_doc(socket_b, """
      subscription { echoed { id message } }
      """)

    assert_reply sub_b, :ok, %{subscriptionId: _}

    mut_a =
      push_doc(socket_a, """
      mutation { echo(message: "from-a") { id message } }
      """)

    assert_reply mut_a, :ok, %{data: %{"echo" => %{"id" => id_a, "message" => "from-a"}}}

    assert_push "subscription:data", %{
      result: %{data: %{"echoed" => %{"id" => ^id_a, "message" => "from-a"}}}
    }

    refute_push "subscription:data", %{result: %{data: %{"echoed" => %{"message" => "from-a"}}}}
  end
end
