defmodule PhxBackendBoilerplate.Cache.CoalescerTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Cache.Coalescer

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
end
