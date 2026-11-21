defmodule PhxBackendBoilerplate.RequestContextTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.RequestContext

  @process_key :phx_backend_boilerplate_request_context

  setup do
    Process.delete(@process_key)
    Logger.reset_metadata([])
    :ok
  end

  test "current/0 returns empty context when unset" do
    assert RequestContext.current() == %{
             request_id: nil,
             correlation_id: nil,
             user_id: nil
           }
  end

  test "start_from_conn/1 generates correlation_id when header absent" do
    Logger.metadata(request_id: "req-abc")

    conn = %Plug.Conn{req_headers: [], assigns: %{}}
    assert :ok = RequestContext.start_from_conn(conn)

    ctx = RequestContext.current()
    assert ctx.request_id == "req-abc"
    assert is_binary(ctx.correlation_id)
    assert byte_size(ctx.correlation_id) == 36
    assert ctx.user_id == nil

    assert Logger.metadata()[:request_id] == "req-abc"
    assert Logger.metadata()[:correlation_id] == ctx.correlation_id
  end

  test "start_from_conn/1 honors valid inbound x-correlation-id" do
    Logger.metadata(request_id: "req-1")

    conn = %Plug.Conn{
      req_headers: [{"x-correlation-id", "journey-abc.123_XYZ"}],
      assigns: %{}
    }

    assert :ok = RequestContext.start_from_conn(conn)
    assert RequestContext.current().correlation_id == "journey-abc.123_XYZ"
    assert Logger.metadata()[:correlation_id] == "journey-abc.123_XYZ"
  end

  test "start_from_conn/1 rejects malformed correlation ids and generates a new one" do
    Logger.metadata(request_id: "req-1")

    for bad <- ["", "has spaces", "bad@id", String.duplicate("a", 129)] do
      Process.delete(@process_key)
      Logger.reset_metadata(request_id: "req-1")

      conn = %Plug.Conn{req_headers: [{"x-correlation-id", bad}], assigns: %{}}
      assert :ok = RequestContext.start_from_conn(conn)
      assert RequestContext.current().correlation_id != bad
      assert is_binary(RequestContext.current().correlation_id)
    end
  end

  test "start_from_conn/1 reads current_user_id from assigns" do
    Logger.metadata(request_id: "req-1")

    conn = %Plug.Conn{
      req_headers: [],
      assigns: %{current_user_id: "user-42"}
    }

    assert :ok = RequestContext.start_from_conn(conn)
    assert RequestContext.current().user_id == "user-42"
    assert Logger.metadata()[:user_id] == "user-42"
  end

  test "put_user_id/1 updates process dict and Logger metadata" do
    Logger.metadata(request_id: "req-1")
    RequestContext.start_from_conn(%Plug.Conn{req_headers: [], assigns: %{}})

    assert :ok = RequestContext.put_user_id("user-99")
    assert RequestContext.current().user_id == "user-99"
    assert Logger.metadata()[:user_id] == "user-99"
  end

  test "propagation_headers/0 emits request_id and correlation_id" do
    assert RequestContext.propagation_headers() == []

    Logger.metadata(request_id: "req-1")

    RequestContext.start_from_conn(%Plug.Conn{
      req_headers: [{"x-correlation-id", "corr-1"}],
      assigns: %{}
    })

    headers = RequestContext.propagation_headers()
    assert {"x-request-id", "req-1"} in headers
    assert {"x-correlation-id", "corr-1"} in headers
    refute Enum.any?(headers, fn {k, _} -> k == "x-user-id" end)
  end

  test "with/2 restores previous context including nil" do
    Logger.metadata(request_id: "outer-req")

    RequestContext.start_from_conn(%Plug.Conn{
      req_headers: [{"x-correlation-id", "outer-corr"}],
      assigns: %{}
    })

    outer = RequestContext.current()

    inner_outcome =
      RequestContext.with(
        %{request_id: "inner-req", correlation_id: "inner-corr", user_id: nil},
        fn ->
          assert RequestContext.current().correlation_id == "inner-corr"
          :inner
        end
      )

    assert inner_outcome == :inner
    assert RequestContext.current() == outer

    RequestContext.with(nil, fn ->
      assert RequestContext.current() == %{
               request_id: nil,
               correlation_id: nil,
               user_id: nil
             }
    end)

    assert RequestContext.current() == outer
  end

  test "Task.async without wrap does not inherit context" do
    Logger.metadata(request_id: "req-1")

    RequestContext.start_from_conn(%Plug.Conn{
      req_headers: [{"x-correlation-id", "corr-1"}],
      assigns: %{}
    })

    task =
      Task.async(fn ->
        RequestContext.current()
      end)

    assert Task.await(task) == %{
             request_id: nil,
             correlation_id: nil,
             user_id: nil
           }
  end

  test "RequestContext.async/1 propagates context and Logger metadata into the child" do
    Logger.metadata(request_id: "req-1")

    RequestContext.start_from_conn(%Plug.Conn{
      req_headers: [{"x-correlation-id", "corr-1"}],
      assigns: %{current_user_id: "user-7"}
    })

    task =
      RequestContext.async(fn ->
        {RequestContext.current(), Logger.metadata()[:correlation_id],
         Logger.metadata()[:user_id]}
      end)

    {ctx, corr_meta, user_meta} = Task.await(task)
    assert ctx.correlation_id == "corr-1"
    assert ctx.request_id == "req-1"
    assert ctx.user_id == "user-7"
    assert corr_meta == "corr-1"
    assert user_meta == "user-7"
  end
end
