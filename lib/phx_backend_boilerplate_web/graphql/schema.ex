defmodule PhxBackendBoilerplateWeb.Graphql.Schema do
  @moduledoc """
  Code-first Absinthe schema for the GraphQL integration demo.

  Covers query, mutation, and subscription so each GraphQL method can be verified.
  """

  use Absinthe.Schema

  import_types(PhxBackendBoilerplateWeb.Graphql.Schema.DemoTypes)

  alias PhxBackendBoilerplateWeb.Graphql.Resolvers.Demo

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
    @desc "Receives messages published by the echo mutation"
    field :echoed, non_null(:echo_message) do
      config(fn _args, _info ->
        {:ok, topic: "demo:echo"}
      end)
    end
  end
end
