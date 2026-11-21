defmodule PhxBackendBoilerplate.Cache.Stampede do
  @moduledoc """
  Cluster-wide stampede protection via Redis `put_new` locks on L2.

  Lock keys are strings: `"swr:lock:" <> key`. Losers never retry the lock;
  on a miss they poll L2 with capped exponential backoff until the value
  appears or the deadline expires.
  """

  alias PhxBackendBoilerplate.Cache.L2
  alias PhxBackendBoilerplate.Deadline

  @lock_prefix "swr:lock:"
  @initial_backoff_ms 10
  @max_backoff_ms 200

  @doc """
  Attempts to acquire the refresh/load lock for `key`.

  Returns `:acquired` or `:contended`. Emits
  `[:phx_backend_boilerplate, :swr, :lock, :stop]`.
  """
  def try_lock(key, lock_ttl_ms) when is_binary(key) and is_integer(lock_ttl_ms) do
    lock_key = lock_key(key)
    start = System.monotonic_time()

    lock_outcome =
      case L2.put_new(lock_key, true, ttl: lock_ttl_ms) do
        {:ok, true} -> :acquired
        {:ok, false} -> :contended
        {:error, _reason} -> :contended
      end

    :telemetry.execute(
      [:phx_backend_boilerplate, :swr, :lock, :stop],
      %{duration: System.monotonic_time() - start},
      %{key: key, result: lock_outcome}
    )

    lock_outcome
  end

  @doc """
  Deletes the lock key (best-effort). Safe if already expired.
  """
  def unlock(key) when is_binary(key) do
    _ = L2.delete(lock_key(key))
    :ok
  end

  @doc """
  Polls L2 for `key` until a value appears or the deadline is exceeded.

  Backoff: 10ms → 20 → 40 → 80 → cap 200ms.
  """
  def poll_until_value(key, opts \\ []) when is_binary(key) do
    get_fun = Keyword.get(opts, :get_fun, &l2_get/1)
    sleep_fun = Keyword.get(opts, :sleep_fun, &Process.sleep/1)
    deadline_remaining = Keyword.get(opts, :deadline_remaining, &Deadline.remaining/0)

    do_poll(key, get_fun, sleep_fun, deadline_remaining, @initial_backoff_ms)
  end

  def lock_key(key) when is_binary(key), do: @lock_prefix <> key

  defp do_poll(key, get_fun, sleep_fun, deadline_remaining, backoff) do
    case deadline_remaining.() do
      0 ->
        {:error, :deadline_exceeded}

      remaining ->
        case get_fun.(key) do
          {:ok, value} ->
            {:ok, value}

          :miss ->
            sleep_ms =
              case remaining do
                nil -> backoff
                ms -> min(backoff, ms)
              end

            if sleep_ms <= 0 do
              {:error, :deadline_exceeded}
            else
              sleep_fun.(sleep_ms)
              next = min(backoff * 2, @max_backoff_ms)
              do_poll(key, get_fun, sleep_fun, deadline_remaining, next)
            end
        end
    end
  end

  defp l2_get(key) do
    case L2.fetch(key) do
      {:ok, value} -> {:ok, value}
      {:error, %Nebulex.KeyError{}} -> :miss
      {:error, _} -> :miss
    end
  end
end
