defmodule PhxBackendBoilerplate.HTTPTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Deadline
  alias PhxBackendBoilerplate.HTTP

  setup do
    Process.delete(:phx_backend_boilerplate_request_deadline)
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
end
