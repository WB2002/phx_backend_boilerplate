defmodule PhxBackendBoilerplateWeb.Plugs.RequestContext do
  @moduledoc """
  Installs request/correlation tracing after `Plug.RequestId`.

  Assigns `:request_id` and `:correlation_id` on the conn and sets the
  `x-correlation-id` response header. Logger metadata is updated via
  `PhxBackendBoilerplate.RequestContext`.
  """

  import Plug.Conn

  alias PhxBackendBoilerplate.RequestContext

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    :ok = RequestContext.start_from_conn(conn)
    ctx = RequestContext.current()

    conn
    |> assign(:request_id, ctx.request_id)
    |> assign(:correlation_id, ctx.correlation_id)
    |> put_resp_header("x-correlation-id", ctx.correlation_id)
  end
end
