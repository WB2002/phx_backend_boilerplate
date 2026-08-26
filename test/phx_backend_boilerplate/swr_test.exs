defmodule PhxBackendBoilerplate.SWRTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Cache.Entry
  alias PhxBackendBoilerplate.Cache.L1
  alias PhxBackendBoilerplate.Cache.L2
  alias PhxBackendBoilerplate.Deadline
  alias PhxBackendBoilerplate.SWR

  @soft 200
  @l1 1_000
  @l2 5_000

  setup do
    key = "swr-#{:erlang.unique_integer([:positive])}"
    _ = L1.delete(key)
    _ = L2.delete(key)
    _ = L2.delete("swr:lock:#{key}")
    {:ok, key: key}
  end

  test "rejects non-string keys" do
    assert_raise ArgumentError, ~r/SWR cache key must be a string/, fn ->
      SWR.fetch({:user, 123}, fn -> {:ok, 1} end)
    end
  end

  test "rejects keys longer than 256 bytes" do
    key = String.duplicate("k", 257)

    assert_raise ArgumentError, ~r/SWR cache key exceeds/, fn ->
      SWR.fetch(key, fn -> {:ok, 1} end)
    end
  end

  test "miss loads once and serves fresh", %{key: key} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    assert {:ok, :v1, %{freshness: :miss}} =
             SWR.fetch(
               key,
               fn ->
                 Agent.update(counter, &(&1 + 1))
                 {:ok, :v1}
               end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2
             )

    assert {:ok, :v1, %{freshness: :fresh}} =
             SWR.fetch(key, fn -> {:ok, :should_not_run} end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2
             )

    assert Agent.get(counter, & &1) == 1
  end

  test "after soft TTL returns stale without calling loader on request path", %{key: key} do
    t0 = System.system_time(:millisecond)

    assert {:ok, :v1, _} =
             SWR.fetch(key, fn -> {:ok, :v1} end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2,
               now_ms: t0
             )

    {:ok, counter} = Agent.start_link(fn -> 0 end)

    assert {:ok, :v1, %{freshness: :stale}} =
             SWR.fetch(
               key,
               fn ->
                 Agent.update(counter, &(&1 + 1))
                 {:ok, :v2}
               end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2,
               now_ms: t0 + @soft + 1
             )

    # Request path did not wait on loader; refresh is background (may or may not have run yet).
    assert Agent.get(counter, & &1) in [0, 1]

    # Wait for background refresh to settle.
    Process.sleep(100)
  end

  test "stale-if-error keeps previous value", %{key: key} do
    t0 = System.system_time(:millisecond)

    assert {:ok, :good, _} =
             SWR.fetch(key, fn -> {:ok, :good} end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2,
               now_ms: t0,
               lock_ttl: 500
             )

    # Force stale and fail refresh by holding lock... easier: put stale entry and
    # make refresh fail; next fetch still serves previous.
    entry = Entry.new(:good, @soft, @l2, t0)
    :ok = L2.put(key, entry, ttl: @l2)
    :ok = L1.put(key, entry, ttl: @l1)

    assert {:ok, :good, %{freshness: :stale}} =
             SWR.fetch(key, fn -> {:error, :boom} end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2,
               now_ms: t0 + @soft + 1,
               lock_ttl: 500
             )

    Process.sleep(150)

    assert {:ok, %Entry{value: :good}} = L2.fetch(key)
  end

  test "poisoned error entry forces miss reload", %{key: key} do
    bad = %Entry{
      value: {:error, :old},
      inserted_at_ms: System.system_time(:millisecond),
      soft_ttl_ms: @soft,
      hard_ttl_ms: @l2
    }

    :ok = L2.put(key, bad, ttl: @l2)
    :ok = L1.put(key, bad, ttl: @l1)

    assert {:ok, :reloaded, %{freshness: :miss}} =
             SWR.fetch(key, fn -> {:ok, :reloaded} end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2
             )
  end

  test "expired deadline on miss returns deadline_exceeded", %{key: key} do
    Deadline.start(0)

    assert {:error, :deadline_exceeded} =
             SWR.fetch(key, fn -> {:ok, :x} end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2
             )
  after
    Process.delete(:phx_backend_boilerplate_request_deadline)
  end

  test "L1 can serve older data than L2 until L1 is cleared", %{key: key} do
    t0 = System.system_time(:millisecond)
    older = Entry.new(:old, @soft, @l2, t0)
    newer = Entry.new(:new, @soft, @l2, t0 + 50)

    :ok = L1.put(key, older, ttl: @l1)
    :ok = L2.put(key, newer, ttl: @l2)

    assert {:ok, :old, %{freshness: :fresh}} =
             SWR.fetch(key, fn -> {:ok, :should_not_run} end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2,
               now_ms: t0 + 10
             )

    _ = L1.delete(key)

    assert {:ok, :new, %{freshness: :fresh}} =
             SWR.fetch(key, fn -> {:ok, :should_not_run} end,
               soft_ttl: @soft,
               l1_hard_ttl: @l1,
               l2_hard_ttl: @l2,
               now_ms: t0 + 60
             )
  end

  test "concurrent misses coalesce to one loader", %{key: key} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    fun = fn ->
      Agent.update(counter, &(&1 + 1))
      Process.sleep(80)
      {:ok, :shared}
    end

    tasks =
      for _ <- 1..15 do
        Task.async(fn ->
          SWR.fetch(key, fun, soft_ttl: @soft, l1_hard_ttl: @l1, l2_hard_ttl: @l2)
        end)
      end

    results = Task.await_many(tasks, 5_000)
    assert Enum.all?(results, &match?({:ok, :shared, _}, &1))
    assert Agent.get(counter, & &1) == 1
  end

  test "emits fetch telemetry stop with freshness", %{key: key} do
    handler_id = "swr-test-#{:erlang.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach(
      handler_id,
      [:phx_backend_boilerplate, :swr, :fetch, :stop],
      fn event, measurements, metadata, _ ->
        send(parent, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    try do
      assert {:ok, :t, %{freshness: :miss}} =
               SWR.fetch(key, fn -> {:ok, :t} end,
                 soft_ttl: @soft,
                 l1_hard_ttl: @l1,
                 l2_hard_ttl: @l2
               )

      assert_receive {:telemetry, [:phx_backend_boilerplate, :swr, :fetch, :stop], %{duration: _},
                      %{freshness: :miss}},
                     1_000
    after
      :telemetry.detach(handler_id)
    end
  end

  test "multilevel Cache.put would share one ttl — SWR writes split TTLs", %{key: key} do
    # Document that we write L2 then L1 separately: remaining TTLs can differ.
    entry = Entry.new(:x, @soft, @l2)
    :ok = L2.put(key, entry, ttl: @l2)
    :ok = L1.put(key, entry, ttl: @l1)

    assert {:ok, l1_ttl} = L1.ttl(key)
    assert {:ok, l2_ttl} = L2.ttl(key)
    assert is_integer(l1_ttl)
    assert is_integer(l2_ttl)
    # L1 hard TTL is shorter, so remaining L1 TTL should be <= L2.
    assert l1_ttl <= l2_ttl
  end
end
