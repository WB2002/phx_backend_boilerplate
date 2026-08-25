defmodule PhxBackendBoilerplate.Cache.StampedeTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Cache.L2
  alias PhxBackendBoilerplate.Cache.Stampede
  alias PhxBackendBoilerplate.Deadline

  setup do
    key = "stampede-#{:erlang.unique_integer([:positive])}"
    _ = L2.delete(key)
    _ = L2.delete(Stampede.lock_key(key))
    {:ok, key: key}
  end

  test "only one process acquires the lock", %{key: key} do
    results =
      1..10
      |> Enum.map(fn _ ->
        Task.async(fn -> Stampede.try_lock(key, 2_000) end)
      end)
      |> Task.await_many(5_000)

    assert Enum.count(results, &(&1 == :acquired)) == 1
    assert Enum.count(results, &(&1 == :contended)) == 9
    Stampede.unlock(key)
  end

  test "poll waits for L2 value without retrying lock", %{key: key} do
    poller =
      Task.async(fn ->
        Deadline.start(2_000)

        Stampede.poll_until_value(key,
          get_fun: fn k ->
            case L2.fetch(k) do
              {:ok, v} -> {:ok, v}
              _ -> :miss
            end
          end
        )
      end)

    Process.sleep(30)
    :ok = L2.put(key, :appeared, ttl: 5_000)

    assert {:ok, :appeared} = Task.await(poller, 3_000)
  end

  test "poll returns deadline_exceeded when budget is exhausted", %{key: key} do
    Deadline.start(30)

    assert {:error, :deadline_exceeded} =
             Stampede.poll_until_value(key,
               get_fun: fn _ -> :miss end
             )
  after
    Process.delete(:phx_backend_boilerplate_request_deadline)
  end
end
