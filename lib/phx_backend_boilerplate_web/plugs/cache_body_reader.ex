defmodule PhxBackendBoilerplateWeb.Plugs.CacheBodyReader do
  @moduledoc """
  Caches the raw request body for Stripe webhook signature verification.

  Only stores `conn.assigns.raw_body` for `POST /api/webhooks/stripe`.
  """

  @webhook_path "/api/webhooks/stripe"

  @doc false
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, body, maybe_cache(conn, body)}

      other ->
        other
    end
  end

  defp maybe_cache(%Plug.Conn{request_path: @webhook_path, method: "POST"} = conn, body) do
    Plug.Conn.assign(conn, :raw_body, body)
  end

  defp maybe_cache(conn, _body), do: conn
end
