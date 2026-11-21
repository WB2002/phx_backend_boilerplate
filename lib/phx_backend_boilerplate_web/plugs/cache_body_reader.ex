defmodule PhxBackendBoilerplateWeb.Plugs.CacheBodyReader do
  @moduledoc """
  Caches the raw request body for Stripe webhook signature verification.

  Only stores `conn.assigns.raw_body` for `POST /api/webhooks/stripe`.

  Caps body reads on `/api/graphql` to the GraphQL envelope budget so chunked
  requests cannot bypass `GraphqlBodyLimit`.
  """

  alias PhxBackendBoilerplateWeb.Graphql.Config

  @webhook_path "/api/webhooks/stripe"
  @envelope_slack_bytes 4_096

  @doc false
  def read_body(conn, opts) do
    opts = maybe_cap_graphql_length(conn, opts)

    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, body, maybe_cache(conn, body)}

      other ->
        other
    end
  end

  defp maybe_cap_graphql_length(%Plug.Conn{path_info: ["api", "graphql" | _]}, opts) do
    max_bytes = Config.max_query_bytes() + @envelope_slack_bytes
    Keyword.put(opts, :length, min(Keyword.get(opts, :length, max_bytes), max_bytes))
  end

  defp maybe_cap_graphql_length(_conn, opts), do: opts

  defp maybe_cache(%Plug.Conn{request_path: @webhook_path, method: "POST"} = conn, body) do
    Plug.Conn.assign(conn, :raw_body, body)
  end

  defp maybe_cache(conn, _body), do: conn
end
