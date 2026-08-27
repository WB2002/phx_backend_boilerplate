defmodule PhxBackendBoilerplateWeb.Graphql.Config do
  @moduledoc """
  Shared GraphQL limits and Absinthe options for HTTP and WebSocket entrypoints.
  """

  @doc """
  Returns Absinthe options for complexity and token limits.
  """
  @spec absinthe_options() :: keyword()
  def absinthe_options do
    [
      analyze_complexity: true,
      max_complexity: max_complexity(),
      token_limit: token_limit()
    ]
  end

  @doc """
  Returns the per-user echo subscription topic for the given user id.
  """
  @spec echo_topic(String.t()) :: String.t()
  def echo_topic(user_id) when is_binary(user_id), do: "user:#{user_id}:echo"

  @spec max_complexity() :: pos_integer()
  def max_complexity do
    graphql_config()
    |> Keyword.get(:max_complexity, 100)
  end

  @spec token_limit() :: pos_integer()
  def token_limit do
    graphql_config()
    |> Keyword.get(:token_limit, 2000)
  end

  @spec max_query_bytes() :: pos_integer()
  def max_query_bytes do
    graphql_config()
    |> Keyword.get(:max_query_bytes, 16_384)
  end

  @spec max_subscriptions() :: pos_integer()
  def max_subscriptions do
    graphql_config()
    |> Keyword.get(:max_subscriptions, 4)
  end

  @spec max_depth() :: pos_integer()
  def max_depth do
    graphql_config()
    |> Keyword.get(:max_depth, 10)
  end

  @spec max_list_page_size() :: pos_integer()
  def max_list_page_size do
    graphql_config()
    |> Keyword.get(:max_list_page_size, 50)
  end

  defp graphql_config do
    Application.get_env(:phx_backend_boilerplate, :graphql, [])
  end
end
