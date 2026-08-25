defmodule PhxBackendBoilerplate.Cache.Coalescer do
  @moduledoc """
  Per-node request coalescing (singleflight).

  Concurrent misses for the same key on one VM share one leader. Waiters
  await the leader's result. If the leader dies, waiters get
  `{:error, :coalescer_crash}` and a later `fetch/3` can elect a new leader.
  """

  use GenServer

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Runs `fun` as the coalescer leader for `key`, or awaits an existing leader.

  Returns whatever `fun` returns for the leader, or the leader's result for
  waiters. On leader crash: `{:error, :coalescer_crash}`.
  """
  def run(key, fun) when is_binary(key) and is_function(fun, 0) do
    case GenServer.call(__MODULE__, {:join, key}, :infinity) do
      :leader ->
        lead(key, fun)

      {:await, ref} ->
        receive do
          {^ref, result} -> result
        end
    end
  end

  @doc false
  def leader_pid(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:leader_pid, key})
  end

  @impl true
  def init(_opts) do
    {:ok, %{keys: %{}}}
  end

  @impl true
  def handle_call({:join, key}, {from_pid, _}, state) do
    case Map.get(state.keys, key) do
      nil ->
        ref = Process.monitor(from_pid)

        entry = %{
          leader: from_pid,
          monitor_ref: ref,
          waiters: []
        }

        {:reply, :leader, put_in(state.keys[key], entry)}

      %{leader: _leader, waiters: waiters} = entry ->
        waiter_ref = make_ref()
        entry = %{entry | waiters: [{from_pid, waiter_ref} | waiters]}
        {:reply, {:await, waiter_ref}, put_in(state.keys[key], entry)}
    end
  end

  def handle_call({:leader_pid, key}, _from, state) do
    pid =
      case Map.get(state.keys, key) do
        %{leader: leader} -> leader
        nil -> nil
      end

    {:reply, pid, state}
  end

  def handle_call({:done, key, result}, {from_pid, _}, state) do
    case Map.get(state.keys, key) do
      %{leader: ^from_pid, monitor_ref: ref, waiters: waiters} ->
        Process.demonitor(ref, [:flush])
        notify_waiters(waiters, result)
        {:reply, :ok, %{state | keys: Map.delete(state.keys, key)}}

      _ ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    case Enum.find(state.keys, fn {_key, %{monitor_ref: mref}} -> mref == ref end) do
      {key, %{leader: ^pid, waiters: waiters}} ->
        notify_waiters(waiters, {:error, :coalescer_crash})
        {:noreply, %{state | keys: Map.delete(state.keys, key)}}

      _ ->
        {:noreply, state}
    end
  end

  defp lead(key, fun) do
    try do
      result = fun.()
      GenServer.call(__MODULE__, {:done, key, result}, :infinity)
      result
    catch
      kind, reason ->
        # Best-effort notify; GenServer may already have handled :DOWN.
        _ = GenServer.call(__MODULE__, {:done, key, {:error, :coalescer_crash}}, :infinity)
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp notify_waiters(waiters, result) do
    Enum.each(waiters, fn {pid, ref} ->
      send(pid, {ref, result})
    end)
  end
end
