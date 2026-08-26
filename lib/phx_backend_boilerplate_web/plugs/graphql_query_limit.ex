defmodule PhxBackendBoilerplateWeb.Plugs.GraphqlQueryLimit do
  @moduledoc """
  Rejects GraphQL documents that exceed the configured byte limit before Absinthe parses them.
  """

  import Plug.Conn

  alias PhxBackendBoilerplateWeb.Graphql.Config

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    max_bytes = max_query_bytes()

    case query_string(conn) do
      query when is_binary(query) and byte_size(query) > max_bytes ->
        conn
        |> put_status(413)
        |> Phoenix.Controller.json(%{
          errors: %{detail: "GraphQL query exceeds maximum size of #{max_bytes} bytes"}
        })
        |> halt()

      _ ->
        conn
    end
  end

  defp query_string(%Plug.Conn{body_params: %{"query" => query}}) when is_binary(query), do: query

  defp query_string(%Plug.Conn{params: %{"query" => query}}) when is_binary(query), do: query

  defp query_string(_conn), do: nil

  defp max_query_bytes, do: Config.max_query_bytes()
end
