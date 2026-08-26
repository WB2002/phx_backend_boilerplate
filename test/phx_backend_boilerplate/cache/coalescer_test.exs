defmodule PhxBackendBoilerplate.Cache.CoalescerTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Cache.Coalescer
  alias PhxBackendBoilerplate.Deadline

  test "coalesces concurrent runners to a single leader invocation" do
    key = "coal-#{:erlang.unique_integer([:positive])}"
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    fun = fn ->
      Agent.update(counter, &(&1 + 1))
      Process.sleep(50)
      :ok
    end

    tasks =
      for _ <- 1..20 do
        Task.async(fn -> Coalescer.run(key, fun) end)
      end

    results = Task.await_many(tasks, 5_000)

    assert Enum.all?(results, &(&1 == :ok))
    assert Agent.get(counter, & &1) == 1
  end

  test "leader kill returns coalescer_crash and allows a new generation" do
    key = "coal-kill-#{:erlang.unique_integer([:positive])}"
    parent = self()

    spawn(fn ->
      Coalescer.run(key, fn ->
        send(parent, {:leader_started, self()})
        Process.sleep(5_000)
        :never
      end)
    end)

    assert_receive {:leader_started, leader_pid}, 1_000

    waiter =
      Task.async(fn ->
        Coalescer.run(key, fn -> :should_not_run end)
      end)

    # Give waiter time to join.
    Process.sleep(20)
    Process.exit(leader_pid, :kill)

    assert {:error, :coalescer_crash} = Task.await(waiter, 2_000)

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    assert :ok =
             Coalescer.run(key, fn ->
               Agent.update(counter, &(&1 + 1))
               :ok
             end)

    assert Agent.get(counter, & &1) == 1
  end

  test "expired deadline before join returns deadline_exceeded without invoking fun" do
    key = "coal-expired-#{:erlang.unique_integer([:positive])}"
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Deadline.start(0)

    assert {:error, :deadline_exceeded} =
             Coalescer.run(key, fn ->
               Agent.update(counter, &(&1 + 1))
               :ok
             end)

    assert Agent.get(counter, & &1) == 0
  after
    Process.delete(:phx_backend_boilerplate_request_deadline)
  end

  test "waiter times out when leader exceeds budget; leader still completes" do
    key = "coal-waiter-#{:erlang.unique_integer([:positive])}"
    parent = self()

    leader =
      Task.async(fn ->
        Coalescer.run(key, fn ->
          send(parent, :leader_running)
          Process.sleep(500)
          :leader_done
        end)
      end)

    assert_receive :leader_running, 1_000

    waiter =
      Task.async(fn ->
        Deadline.start(50)

        Coalescer.run(key, fn -> :should_not_run end)
      end)

    assert {:error, :deadline_exceeded} = Task.await(waiter, 2_000)
    assert :leader_done = Task.await(leader, 2_000)

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    assert :ok =
             Coalescer.run(key, fn ->
               Agent.update(counter, &(&1 + 1))
               :ok
             end)

    assert Agent.get(counter, & &1) == 1
  after
    Process.delete(:phx_backend_boilerplate_request_deadline)
  end

  test "timed-out waiter does not prevent other waiters from receiving the result" do
    key = "coal-leave-#{:erlang.unique_integer([:positive])}"
    parent = self()

    leader =
      Task.async(fn ->
        Coalescer.run(key, fn ->
          send(parent, :leader_running)
          Process.sleep(500)
          :shared_result
        end)
      end)

    assert_receive :leader_running, 1_000

    short_waiter =
      Task.async(fn ->
        Deadline.start(50)

        Coalescer.run(key, fn -> :should_not_run end)
      end)

    long_waiter =
      Task.async(fn ->
        Deadline.start(2_000)

        Coalescer.run(key, fn -> :should_not_run end)
      end)

    assert {:error, :deadline_exceeded} = Task.await(short_waiter, 2_000)
    assert :shared_result = Task.await(long_waiter, 3_000)
    assert :shared_result = Task.await(leader, 3_000)
  after
    Process.delete(:phx_backend_boilerplate_request_deadline)
  end
end
