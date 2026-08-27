defmodule PhxBackendBoilerplate.HTTPTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Deadline
  alias PhxBackendBoilerplate.HTTP
  alias PhxBackendBoilerplate.RequestContext

  setup do
    Process.delete(:phx_backend_boilerplate_request_deadline)
    Process.delete(:phx_backend_boilerplate_request_context)
    Logger.reset_metadata([])
    :ok
  end

  test "new/1 forces retry: false even when caller asks for retries" do
    request = HTTP.new(retry: :transient)

    assert request.options.retry == false
  end

  test "get/2 returns stubbed response via Req.Test plug" do
    stub_name = :"http_get_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      assert conn.request_path == "/hello"
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, %Req.Response{status: 200, body: %{"ok" => true}}} =
             HTTP.get("/hello",
               base_url: "https://example.test",
               plug: {Req.Test, stub_name}
             )
  end

  test "request/1 returns error tuple for transport failures" do
    stub_name = :"http_err_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Req.TransportError{reason: :timeout}} =
             HTTP.request(
               method: :get,
               url: "https://example.test/timeout",
               plug: {Req.Test, stub_name}
             )
  end

  test "attaches x-request-timeout-ms when deadline is set" do
    Deadline.start(2_000)
    stub_name = :"http_deadline_hdr_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      assert [value] = Plug.Conn.get_req_header(conn, "x-request-timeout-ms")
      assert String.to_integer(value) > 0
      assert String.to_integer(value) <= 2_000
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, %{status: 200}} =
             HTTP.get("/hello",
               base_url: "https://example.test",
               plug: {Req.Test, stub_name}
             )
  end

  test "attaches x-request-id and x-correlation-id when RequestContext is set" do
    Logger.metadata(request_id: "req-out-1")

    RequestContext.start_from_conn(%Plug.Conn{
      req_headers: [{"x-correlation-id", "corr-out-1"}],
      assigns: %{}
    })

    stub_name = :"http_ctx_hdr_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-request-id") == ["req-out-1"]
      assert Plug.Conn.get_req_header(conn, "x-correlation-id") == ["corr-out-1"]
      assert Plug.Conn.get_req_header(conn, "x-user-id") == []
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, %{status: 200}} =
             HTTP.get("/hello",
               base_url: "https://example.test",
               plug: {Req.Test, stub_name}
             )
  end

  test "expired deadline skips Req and returns :deadline_exceeded" do
    Deadline.start_at(System.monotonic_time(:millisecond) - 1)
    stub_name = :"http_expired_#{System.unique_integer([:positive])}"
    called? = :atomics.new(1, signed: false)

    Req.Test.stub(stub_name, fn conn ->
      :atomics.put(called?, 1, 1)
      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:error, :deadline_exceeded} =
             HTTP.get("/hello",
               base_url: "https://example.test",
               plug: {Req.Test, stub_name}
             )

    assert :atomics.get(called?, 1) == 0
  end

  test "transport timeout when remaining < config maps to :deadline_exceeded" do
    Deadline.start(50)
    stub_name = :"http_dl_lt_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, :deadline_exceeded} =
             HTTP.get("/timeout",
               base_url: "https://example.test",
               receive_timeout: 15_000,
               plug: {Req.Test, stub_name}
             )
  end

  test "transport timeout when config < remaining stays transport error" do
    Deadline.start(15_000)
    stub_name = :"http_cfg_lt_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %Req.TransportError{reason: :timeout}} =
             HTTP.get("/timeout",
               base_url: "https://example.test",
               receive_timeout: 100,
               plug: {Req.Test, stub_name}
             )
  end

  test "transport timeout when remaining == config maps to :deadline_exceeded" do
    # start_at so remaining is exactly known before the request path reads it
    now = System.monotonic_time(:millisecond)
    budget = 200
    Deadline.start_at(now + budget)
    stub_name = :"http_eq_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    remaining = Deadline.remaining()

    assert {:error, :deadline_exceeded} =
             HTTP.get("/timeout",
               base_url: "https://example.test",
               receive_timeout: remaining,
               plug: {Req.Test, stub_name}
             )
  end

  test "rejects responses larger than max_body_bytes" do
    stub_name = :"http_big_#{System.unique_integer([:positive])}"

    Req.Test.stub(stub_name, fn conn ->
      Plug.Conn.send_resp(conn, 200, String.duplicate("a", 64))
    end)

    assert {:error, :response_too_large} =
             HTTP.get("/big",
               base_url: "https://example.test",
               plug: {Req.Test, stub_name},
               decode_body: false,
               max_body_bytes: 16
             )
  end

  test "aborts streaming before buffering an oversized body" do
    stub_name = :"http_stream_big_#{System.unique_integer([:positive])}"
    # Large enough that a naive full buffer would allocate far more than the cap.
    payload = String.duplicate("x", 100_000)

    Req.Test.stub(stub_name, fn conn ->
      Plug.Conn.send_resp(conn, 200, payload)
    end)

    assert {:error, :response_too_large} =
             HTTP.get("/stream-big",
               base_url: "https://example.test",
               plug: {Req.Test, stub_name},
               decode_body: false,
               max_body_bytes: 1_024
             )
  end
end
