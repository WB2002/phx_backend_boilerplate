defmodule PhxBackendBoilerplateWeb.Graphql.Resolvers.Demo do
  @moduledoc """
  Resolvers for the Absinthe integration demo (query / mutation / subscription).
  """

  alias PhxBackendBoilerplateWeb.Endpoint
  alias PhxBackendBoilerplateWeb.Graphql.Config

  @doc false
  def ping(_parent, _args, _resolution), do: {:ok, "pong"}

  @doc false
  def hello(_parent, %{name: name}, _resolution) when is_binary(name) do
    {:ok, "Hello, #{name}!"}
  end

  def hello(_parent, _args, _resolution), do: {:ok, "Hello, world!"}

  @doc false
  def echoes(_parent, _args, _resolution), do: {:ok, []}

  @doc false
  def echo(_parent, %{message: message}, %{context: %{current_user_id: user_id}})
      when is_binary(message) and is_binary(user_id) do
    echo_message = %{id: Ecto.UUID.generate(), message: message}
    topic = Config.echo_topic(user_id)

    :ok = Absinthe.Subscription.publish(Endpoint, echo_message, echoed: topic)

    {:ok, echo_message}
  end
end
