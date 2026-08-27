defmodule PhxBackendBoilerplateWeb.Plugs.GraphqlBodyLimit do
  @moduledoc """
  Rejects GraphQL HTTP requests whose `Content-Length` exceeds the query budget
  plus a small JSON envelope slack, before `Plug.Parsers` allocates the body.
  """

  import Plug.Conn

  alias PhxBackendBoilerplateWeb.Graphql.Config

  @behaviour Plug

  # Overhead for `{"query":"…","variables":{},"operationName":null}` wrappers.
  @envelope_slack_bytes 4_096

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/api/graphql"} = conn, _opts) do
    max_bytes = Config.max_query_bytes() + @envelope_slack_bytes

    case content_length(conn) do
      length when is_integer(length) and length > max_bytes ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          413,
          Jason.encode!(%{
            errors: %{
              detail: "GraphQL request exceeds maximum size of #{max_bytes} bytes"
            }
          })
        )
        |> halt()

      _ ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp content_length(conn) do
    case get_req_header(conn, "content-length") do
      [value | _] ->
        case Integer.parse(value) do
          {n, ""} when n >= 0 -> n
          _ -> nil
        end

      _ ->
        nil
    end
  end
end
