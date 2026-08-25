defmodule PhxBackendBoilerplate.DeadlineTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Deadline

  setup do
    Process.delete(:phx_backend_boilerplate_request_deadline)
    :ok
  end

  test "start/1 sets remaining approximately to timeout" do
    Deadline.start(200)
    rem = Deadline.remaining()
    assert rem != nil
    assert rem <= 200
    assert rem >= 190
    refute Deadline.expired?()
  end

  test "start_at/1 is absolute, not an offset" do
    now = System.monotonic_time(:millisecond)
    Deadline.start_at(now + 80)
    rem = Deadline.remaining()
    assert rem <= 80
    assert rem >= 70
  end

  test "expired? and remaining() == 0 invariant when deadline is set" do
    now = System.monotonic_time(:millisecond)
    Deadline.start_at(now)
    assert Deadline.expired?()
    assert Deadline.remaining() == 0

    Deadline.start_at(now - 1)
    assert Deadline.expired?()
    assert Deadline.remaining() == 0

    Deadline.start(500)
    refute Deadline.expired?()
    assert Deadline.remaining() > 0
    assert Deadline.expired?() == (Deadline.remaining() == 0)
  end

  test "remaining/0 and expired?/0 are nil/false when unset" do
    assert Deadline.current() == nil
    assert Deadline.remaining() == nil
    refute Deadline.expired?()
  end

  test "with/2 restores previous deadline including nil" do
    Deadline.start(1_000)
    outer = Deadline.current()

    result =
      Deadline.with(System.monotonic_time(:millisecond) + 50, fn ->
        assert Deadline.remaining() <= 50
        :inner
      end)

    assert result == :inner
    assert Deadline.current() == outer

    Deadline.with(nil, fn ->
      assert Deadline.current() == nil
    end)

    assert Deadline.current() == outer
  end

  test "from_headers/1 malformed returns nil; 0 is valid" do
    assert Deadline.from_headers([]) == nil
    assert Deadline.from_headers([{"x-request-timeout-ms", "abc"}]) == nil
    assert Deadline.from_headers([{"x-request-timeout-ms", "1.5"}]) == nil
    assert Deadline.from_headers([{"x-request-timeout-ms", "123abc"}]) == nil
    assert Deadline.from_headers([{"x-request-timeout-ms", "-1"}]) == nil
    assert Deadline.from_headers([{"x-request-timeout-ms", ""}]) == nil

    assert Deadline.from_headers([
             {"x-request-timeout-ms", "100"},
             {"x-request-timeout-ms", "200"}
           ]) == nil

    assert Deadline.from_headers([{"x-request-timeout-ms", "0"}]) == 0
    assert Deadline.from_headers([{"x-request-timeout-ms", "1472"}]) == 1472
    assert Deadline.from_headers([{"X-Request-Timeout-Ms", "50"}]) == 50
  end

  test "propagation_headers/0 emits remaining budget" do
    assert Deadline.propagation_headers() == []

    Deadline.start(250)
    assert [{"x-request-timeout-ms", value}] = Deadline.propagation_headers()
    assert String.to_integer(value) == Deadline.remaining()
  end

  test "Task.async without wrap does not inherit deadline" do
    Deadline.start(500)

    task =
      Task.async(fn ->
        Deadline.current()
      end)

    assert Task.await(task) == nil
  end

  test "Deadline.async/1 propagates deadline into the child" do
    Deadline.start(500)

    task =
      Deadline.async(fn ->
        rem = Deadline.remaining()
        {Deadline.current() != nil, rem}
      end)

    {has_deadline, rem} = Task.await(task)
    assert has_deadline
    assert rem > 0
    assert rem <= 500
  end

  test "start_from_conn/2 caps header and uses one mono base" do
    conn = %Plug.Conn{req_headers: [{"x-request-timeout-ms", "50"}]}
    Deadline.start_from_conn(conn, 200)
    rem = Deadline.remaining()
    assert rem <= 50
    assert rem >= 40

    conn = %Plug.Conn{req_headers: [{"x-request-timeout-ms", "5000"}]}
    Deadline.start_from_conn(conn, 200)
    rem = Deadline.remaining()
    assert rem <= 200
    assert rem >= 190

    conn = %Plug.Conn{req_headers: [{"x-request-timeout-ms", "0"}]}
    Deadline.start_from_conn(conn, 200)
    assert Deadline.expired?()
    assert Deadline.remaining() == 0

    conn = %Plug.Conn{req_headers: [{"x-request-timeout-ms", "nope"}]}
    Deadline.start_from_conn(conn, 300)
    rem = Deadline.remaining()
    assert rem <= 300
    assert rem >= 290
  end
end
