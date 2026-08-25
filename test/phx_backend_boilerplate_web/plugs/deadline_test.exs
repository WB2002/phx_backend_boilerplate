defmodule PhxBackendBoilerplateWeb.Plugs.DeadlineTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: true

  alias PhxBackendBoilerplate.Deadline
  alias PhxBackendBoilerplateWeb.Plugs.Deadline, as: DeadlinePlug

  setup do
    Process.delete(:phx_backend_boilerplate_request_deadline)
    :ok
  end

  test "no header starts approximately plug timeout" do
    opts = DeadlinePlug.init(timeout: 500)
    conn = build_conn() |> DeadlinePlug.call(opts)

    refute conn.halted
    rem = Deadline.remaining()
    assert rem <= 500
    assert rem >= 490
  end

  test "malformed header uses plug timeout (not 504)" do
    opts = DeadlinePlug.init(timeout: 400)

    conn =
      build_conn()
      |> put_req_header("x-request-timeout-ms", "not-a-number")
      |> DeadlinePlug.call(opts)

    refute conn.halted
    rem = Deadline.remaining()
    assert rem <= 400
    assert rem >= 390
  end

  test "header shorter than plug timeout shortens remaining" do
    opts = DeadlinePlug.init(timeout: 5_000)

    conn =
      build_conn()
      |> put_req_header("x-request-timeout-ms", "80")
      |> DeadlinePlug.call(opts)

    refute conn.halted
    rem = Deadline.remaining()
    assert rem <= 80
    assert rem >= 70
  end

  test "header larger than plug timeout is capped" do
    opts = DeadlinePlug.init(timeout: 100)

    conn =
      build_conn()
      |> put_req_header("x-request-timeout-ms", "50000")
      |> DeadlinePlug.call(opts)

    refute conn.halted
    rem = Deadline.remaining()
    assert rem <= 100
    assert rem >= 90
  end

  test "header 0 returns 504 and halt" do
    opts = DeadlinePlug.init(timeout: 15_000)

    conn =
      build_conn()
      |> put_req_header("x-request-timeout-ms", "0")
      |> DeadlinePlug.call(opts)

    assert conn.halted
    assert conn.status == 504
    assert Jason.decode!(conn.resp_body) == %{"errors" => %{"detail" => "Gateway Timeout"}}
  end
end
