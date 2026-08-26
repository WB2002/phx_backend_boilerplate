defmodule PhxBackendBoilerplateWeb.GraphqlCase do
  @moduledoc """
  Helpers for authenticated GraphQL HTTP and WebSocket tests.
  """

  import Plug.Conn
  import Phoenix.ConnTest

  alias PhxBackendBoilerplate.Accounts

  use PhxBackendBoilerplateWeb, :verified_routes

  @endpoint PhxBackendBoilerplateWeb.Endpoint

  @doc """
  Registers a user and returns auth bundle plus a conn prepared for GraphQL POSTs.
  """
  def authenticated_graphql_conn(conn \\ build_conn()) do
    {:ok, auth} = Accounts.register(unique_user_attrs())

    conn =
      conn
      |> Map.put(:remote_ip, unique_ip())
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{auth.access_token}")

    {conn, auth}
  end

  @doc """
  POSTs a GraphQL document to `/api/graphql`.
  """
  def graphql_post(conn, query, variables \\ %{}) do
    body = %{"query" => query}

    body =
      if map_size(variables) == 0 do
        body
      else
        Map.put(body, "variables", variables)
      end

    post(conn, ~p"/api/graphql", body)
  end

  @doc false
  def unique_user_attrs do
    n = :erlang.unique_integer([:positive])

    %{
      "email" => "graphql-#{n}@example.com",
      "password" => "password123"
    }
  end

  @doc false
  def unique_ip do
    n = :erlang.unique_integer([:positive])
    {10, 4, rem(div(n, 256), 256), rem(n, 256)}
  end

  @doc """
  Builds a GraphQL query string with many aliased ping fields to exceed complexity.
  """
  def high_complexity_query(count) when is_integer(count) and count > 0 do
    fields = Enum.map_join(1..count, " ", fn n -> "f#{n}: ping" end)
    "{ #{fields} }"
  end

  @doc """
  Builds a GraphQL query string that exceeds the configured token limit.
  """
  def high_token_query(token_count) when is_integer(token_count) and token_count > 0 do
    # Each "ping" is one token; braces add a few more.
    fields = Enum.map_join(1..token_count, " ", fn _ -> "ping" end)
    "{ #{fields} }"
  end

  @doc """
  Builds a query string longer than `max_bytes`.
  """
  def oversized_query(max_bytes) when is_integer(max_bytes) and max_bytes > 0 do
    String.duplicate(" ", max_bytes + 1) <> "{ ping }"
  end
end
