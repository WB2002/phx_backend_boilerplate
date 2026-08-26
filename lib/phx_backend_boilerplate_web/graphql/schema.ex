defmodule PhxBackendBoilerplateWeb.Graphql.Schema do
  @moduledoc """
  Code-first Absinthe schema for the GraphQL integration demo.

  All operations require a valid access JWT on HTTP and WebSocket. Query budgets
  (byte size, token count, complexity) are enforced at the plug/socket layer.
  GraphiQL is dev-only; production GraphQL is authenticated.
  """

  use Absinthe.Schema

  import_types(PhxBackendBoilerplateWeb.Graphql.Schema.DemoTypes)

  alias PhxBackendBoilerplateWeb.Graphql.Config
  alias PhxBackendBoilerplateWeb.Graphql.Middleware.RequireAuth
  alias PhxBackendBoilerplateWeb.Graphql.Resolvers.Demo
  alias PhxBackendBoilerplateWeb.Graphql.SubscriptionBudget

  query do
    @desc "Health / integration check"
    field :ping, non_null(:string) do
      resolve(&Demo.ping/3)
    end

    @desc "Greet by optional name (defaults to world)"
    field :hello, non_null(:string) do
      arg(:name, :string, default_value: "world")
      resolve(&Demo.hello/3)
    end
  end

  mutation do
    @desc "Echo a message and publish it to the echoed subscription"
    field :echo, non_null(:echo_message) do
      arg(:message, non_null(:string))
      resolve(&Demo.echo/3)
    end
  end

  subscription do
    @desc "Receives messages published by the echo mutation for the current user"
    field :echoed, non_null(:echo_message) do
      config(fn _args, info ->
        case info.context do
          %{current_user_id: user_id} when is_binary(user_id) ->
            case SubscriptionBudget.checkout() do
              :ok ->
                {:ok, topic: Config.echo_topic(user_id)}

              {:error, message} ->
                {:error, message}
            end

          _ ->
            {:error, "Unauthorized"}
        end
      end)
    end
  end

  def middleware(middleware, _field, %{identifier: type})
      when type in [:query, :mutation, :subscription] do
    [RequireAuth | middleware]
  end

  def middleware(middleware, _field, _object), do: middleware
end
