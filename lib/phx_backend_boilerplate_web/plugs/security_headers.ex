defmodule PhxBackendBoilerplateWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Sets Content-Security-Policy and companion security headers on every response.

  API paths get a strict CSP (`default-src 'none'`). Paths under `/dev` use a
  looser policy so LiveDashboard and FunWithFlags UI can load scripts/styles.

  Policies are configurable under `PhxBackendBoilerplateWeb.Plugs.SecurityHeaders`.
  """

  import Plug.Conn

  @behaviour Plug

  @default_api_csp "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"

  @default_dev_csp "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self' ws: wss:; frame-ancestors 'none'"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    csp = if dev_path?(conn.request_path), do: dev_csp(), else: api_csp()

    conn
    |> put_resp_header("content-security-policy", csp)
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end

  defp dev_path?("/dev"), do: true
  defp dev_path?("/dev/" <> _), do: true
  defp dev_path?(_), do: false

  defp api_csp do
    config() |> Keyword.get(:api_csp, @default_api_csp)
  end

  defp dev_csp do
    config() |> Keyword.get(:dev_csp, @default_dev_csp)
  end

  defp config do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
  end
end
