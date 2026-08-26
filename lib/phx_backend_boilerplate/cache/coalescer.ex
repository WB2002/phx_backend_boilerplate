defmodule PhxBackendBoilerplate.Cache.Coalescer do
  @moduledoc """
  Per-node request coalescing (singleflight).

  One named GenServer per VM. Concurrent misses for the same key share one
  leader; leader work runs in the caller process. Waiters await the leader's
  result with a timeout aligned to `PhxBackendBoilerplate.Deadline` when set,
  otherwise the app default (15s).

  Returns:

    * whatever `fun` returns for the leader
    * the leader's result for waiters
    * `{:error, :coalescer_crash}` if the leader dies
    * `{:error, :deadline_exceeded}` if the budget expires before join or while waiting
  """

  use GenServer

  alias PhxBackendBoilerplate.Deadline

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Runs `fun` as the coalescer leader for `key`, or awaits an existing leader.

  Returns whatever `fun` returns for the leader, or the leader's result for
  waiters. On leader crash: `{:error, :coalescer_crash}`. On timeout:
  `{:error, :deadline_exceeded}`.
  """
  def run(key, fun) when is_binary(key) and is_function(fun, 0) do
    case timeout_ms() do
      0 -> {:error, :deadline_exceeded}
      timeout -> join_and_run(key, fun, timeout)
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

  @impl true
  def handle_cast({:done, key, from_pid, result}, state) do
    case Map.get(state.keys, key) do
      %{leader: ^from_pid, monitor_ref: ref, waiters: waiters} ->
        Process.demonitor(ref, [:flush])
        notify_waiters(waiters, result)
        {:noreply, %{state | keys: Map.delete(state.keys, key)}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:leave, key, pid, ref}, state) do
    case Map.get(state.keys, key) do
      %{waiters: waiters} = entry ->
        waiters = Enum.reject(waiters, fn {w_pid, w_ref} -> w_pid == pid and w_ref == ref end)
        entry = %{entry | waiters: waiters}
        {:noreply, put_in(state.keys[key], entry)}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:cancel, key, pid}, state) do
    case Map.get(state.keys, key) do
      %{leader: ^pid, monitor_ref: ref, waiters: waiters} ->
        Process.demonitor(ref, [:flush])
        notify_waiters(waiters, {:error, :deadline_exceeded})
        {:noreply, %{state | keys: Map.delete(state.keys, key)}}

      _ ->
        {:noreply, state}
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

  defp join_and_run(key, fun, timeout) do
    try do
      case GenServer.call(__MODULE__, {:join, key}, timeout) do
        :leader ->
          lead(key, fun)

        {:await, ref} ->
          await_result(key, ref, timeout)
      end
    catch
      :exit, {:timeout, _} ->
        GenServer.cast(__MODULE__, {:cancel, key, self()})
        {:error, :deadline_exceeded}
    end
  end

  defp await_result(key, ref, timeout) do
    receive do
      {^ref, result} -> result
    after
      timeout ->
        GenServer.cast(__MODULE__, {:leave, key, self(), ref})
        flush_late(ref)
        {:error, :deadline_exceeded}
    end
  end

  defp flush_late(ref) do
    receive do
      {^ref, _} -> :ok
    after
      0 -> :ok
    end
  end

  defp lead(key, fun) do
    try do
      result = fun.()
      GenServer.cast(__MODULE__, {:done, key, self(), result})
      result
    catch
      kind, reason ->
        GenServer.cast(__MODULE__, {:done, key, self(), {:error, :coalescer_crash}})
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp timeout_ms do
    case Deadline.remaining() do
      nil -> default_timeout_ms()
      0 -> 0
      ms -> ms
    end
  end

  defp default_timeout_ms do
    Application.get_env(:phx_backend_boilerplate, Deadline, [])
    |> Keyword.get(:timeout, 15_000)
  end

  defp notify_waiters(waiters, result) do
    Enum.each(waiters, fn {pid, ref} ->
      send(pid, {ref, result})
    end)
  end
end
