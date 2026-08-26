defmodule PhxBackendBoilerplateWeb.Plugs.Parsers do
  @moduledoc """
  Wraps `Plug.Parsers` and returns 413 JSON instead of raising on oversized bodies.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: Plug.Parsers.init(opts)

  @impl true
  def call(conn, opts) do
    Plug.Parsers.call(conn, opts)
  rescue
    _e in Plug.Parsers.RequestTooLargeError ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        413,
        Jason.encode!(%{errors: %{detail: "Request Entity Too Large"}})
      )
      |> Plug.Conn.halt()
  end
end
