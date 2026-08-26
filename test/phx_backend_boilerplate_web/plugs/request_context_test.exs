defmodule PhxBackendBoilerplateWeb.Plugs.RequestContextTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: true

  alias PhxBackendBoilerplate.RequestContext
  alias PhxBackendBoilerplateWeb.Plugs.RequestContext, as: RequestContextPlug

  @process_key :phx_backend_boilerplate_request_context

  setup do
    Process.delete(@process_key)
    Logger.reset_metadata([])
    :ok
  end

  test "generates correlation_id, assigns conn, and sets response header" do
    Logger.metadata(request_id: "req-from-plug")
    opts = RequestContextPlug.init([])

    conn = build_conn() |> RequestContextPlug.call(opts)

    refute conn.halted
    assert conn.assigns.request_id == "req-from-plug"
    assert is_binary(conn.assigns.correlation_id)
    assert get_resp_header(conn, "x-correlation-id") == [conn.assigns.correlation_id]
    assert Logger.metadata()[:correlation_id] == conn.assigns.correlation_id
    assert RequestContext.current().correlation_id == conn.assigns.correlation_id
  end

  test "echoes valid inbound x-correlation-id" do
    Logger.metadata(request_id: "req-1")
    opts = RequestContextPlug.init([])

    conn =
      build_conn()
      |> put_req_header("x-correlation-id", "journey-xyz")
      |> RequestContextPlug.call(opts)

    assert conn.assigns.correlation_id == "journey-xyz"
    assert get_resp_header(conn, "x-correlation-id") == ["journey-xyz"]
  end

  test "reads current_user_id from assigns into Logger metadata" do
    Logger.metadata(request_id: "req-1")
    opts = RequestContextPlug.init([])

    conn =
      build_conn()
      |> Plug.Conn.assign(:current_user_id, "demo-user")
      |> RequestContextPlug.call(opts)

    assert RequestContext.current().user_id == "demo-user"
    assert Logger.metadata()[:user_id] == "demo-user"
    assert conn.assigns.correlation_id
  end
end
