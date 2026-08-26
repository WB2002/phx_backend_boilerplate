defmodule PhxBackendBoilerplateWeb.Graphql.SubscriptionTest do
  use PhxBackendBoilerplateWeb.ChannelCase, async: false
  use Absinthe.Phoenix.SubscriptionTest, schema: PhxBackendBoilerplateWeb.Graphql.Schema

  alias PhxBackendBoilerplateWeb.GraphqlSocket

  setup do
    {:ok, socket} = connect(GraphqlSocket, %{})
    {:ok, socket} = join_absinthe(socket)
    {:ok, socket: socket}
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
end
