defmodule PhxBackendBoilerplateWeb.Graphql.Resolvers.Demo do
  @moduledoc """
  Resolvers for the Absinthe integration demo (query / mutation / subscription).
  """

  alias PhxBackendBoilerplateWeb.Endpoint

  @doc false
  def ping(_parent, _args, _resolution), do: {:ok, "pong"}

  @doc false
  def hello(_parent, %{name: name}, _resolution) when is_binary(name) do
    {:ok, "Hello, #{name}!"}
  end

  def hello(_parent, _args, _resolution), do: {:ok, "Hello, world!"}

  @doc false
  def echo(_parent, %{message: message}, _resolution) when is_binary(message) do
    echo_message = %{id: Ecto.UUID.generate(), message: message}

    :ok = Absinthe.Subscription.publish(Endpoint, echo_message, echoed: "demo:echo")

    {:ok, echo_message}
  end
end
