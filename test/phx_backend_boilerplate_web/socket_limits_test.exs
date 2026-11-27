defmodule PhxBackendBoilerplateWeb.SocketLimitsTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplateWeb.SocketLimits

  test "rate_limit_connect allows connect when rate limit backend errors" do
    previous = Application.get_env(:phx_backend_boilerplate, SocketLimits, [])

    Application.put_env(
      :phx_backend_boilerplate,
      SocketLimits,
      Keyword.put(previous, :hit, fn _, _, _ -> {:error, :redis_down} end)
    )

    on_exit(fn -> Application.put_env(:phx_backend_boilerplate, SocketLimits, previous) end)

    connect_info = %{peer_data: %{address: {198, 51, 100, 10}}, x_headers: []}

    assert :ok = SocketLimits.rate_limit_connect(connect_info)
  end

  test "checkout_channel cleans up ETS entry via Task.Supervisor when transport exits" do
    before_children = MapSet.new(Task.Supervisor.children(SocketLimits.TaskSupervisor))

    transport_pid =
      start_supervised!(
        {Task,
         fn ->
           receive do
             :stop -> :ok
           end
         end}
      )

    socket = %Phoenix.Socket{transport_pid: transport_pid}

    assert :ok = SocketLimits.checkout_channel(socket)
    assert [{^transport_pid, 1}] = :ets.lookup(SocketLimits.ChannelCounts, transport_pid)

    new_children =
      SocketLimits.TaskSupervisor
      |> Task.Supervisor.children()
      |> Enum.reject(&MapSet.member?(before_children, &1))

    assert [cleanup_pid] = new_children

    cleanup_ref = Process.monitor(cleanup_pid)
    transport_ref = Process.monitor(transport_pid)

    stop_supervised!(Task)
    assert_receive {:DOWN, ^transport_ref, :process, ^transport_pid, _}
    assert_receive {:DOWN, ^cleanup_ref, :process, ^cleanup_pid, :normal}

    assert [] = :ets.lookup(SocketLimits.ChannelCounts, transport_pid)
  end
end
