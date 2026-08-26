defmodule PhxBackendBoilerplateWeb.Graphql.Schema.DemoTypes do
  @moduledoc """
  GraphQL object types for the Absinthe integration demo.
  """

  use Absinthe.Schema.Notation

  @desc "A message echoed by the demo mutation and subscription"
  object :echo_message do
    field :id, non_null(:id)
    field :message, non_null(:string)
  end
end
