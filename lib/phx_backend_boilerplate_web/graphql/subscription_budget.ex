defmodule PhxBackendBoilerplateWeb.Graphql.SubscriptionBudget do
  @moduledoc false

  alias PhxBackendBoilerplateWeb.Graphql.Config

  @key :phx_backend_boilerplate_graphql_subscription_count

  @spec checkout() :: :ok | {:error, String.t()}
  def checkout do
    max = Config.max_subscriptions()
    count = Process.get(@key, 0)

    if count >= max do
      {:error, "Too many GraphQL subscriptions (max #{max})"}
    else
      Process.put(@key, count + 1)
      :ok
    end
  end
end
