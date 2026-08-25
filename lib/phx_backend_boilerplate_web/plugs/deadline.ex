defmodule PhxBackendBoilerplateWeb.Plugs.Deadline do
  @moduledoc """
  Establishes a request deadline at the Phoenix edge **before** Hammer and Regulator.

  Options:

    * `:timeout` — local budget in milliseconds (default from
      `config :phx_backend_boilerplate, PhxBackendBoilerplate.Deadline, timeout: …`,
      fallback `15_000`)

  Reads optional inbound `x-request-timeout-ms` (remaining budget). Malformed
  headers are ignored. Valid `0` (or remaining after cap) that is already
  expired returns `504` with `{"errors":{"detail":"Gateway Timeout"}}`.
  """

  import Plug.Conn

  alias PhxBackendBoilerplate.Deadline

  @behaviour Plug

  @default_timeout 15_000

  @impl true
  def init(opts) do
    timeout =
      Keyword.get_lazy(opts, :timeout, fn ->
        Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Deadline, [])
        |> Keyword.get(:timeout, @default_timeout)
      end)

    unless is_integer(timeout) and timeout >= 0,
      do: raise(ArgumentError, ":timeout must be a non-negative integer")

    %{timeout: timeout}
  end

  @impl true
  def call(conn, %{timeout: timeout}) do
    Deadline.start_from_conn(conn, timeout)

    if Deadline.expired?() do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(504, Jason.encode!(%{errors: %{detail: "Gateway Timeout"}}))
      |> halt()
    else
      conn
    end
  end
end
