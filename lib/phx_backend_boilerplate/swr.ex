defmodule PhxBackendBoilerplate.SWR do
  @moduledoc """
  Stale-while-revalidate fetch with request coalescing and stampede protection.

  Uses Nebulex multilevel cache for reads (`Cache.get`/`fetch`) and explicit
  `L2.put` then `L1.put` writes with split hard TTLs.

  ## Keys

  Keys **must** be binaries. Non-string keys raise `ArgumentError`.

  ## Values

  Cache only serializable terms (maps, lists, primitives). Do not store Ecto
  structs with associations — normalize in the loader before returning
  `{:ok, value}`. Loader errors are never written to the cache (stale-if-error).

  ## Consistency

  L1 is node-local. A refresh updates L2 and the refreshing node's L1; other
  nodes may serve older L1 data until their L1 hard TTL expires (eventual
  consistency). Soft TTL uses wall-clock `inserted_at_ms` and is approximate
  across nodes under clock skew.
  """

  alias PhxBackendBoilerplate.Cache
  alias PhxBackendBoilerplate.Cache.Coalescer
  alias PhxBackendBoilerplate.Cache.Entry
  alias PhxBackendBoilerplate.Cache.L1
  alias PhxBackendBoilerplate.Cache.L2
  alias PhxBackendBoilerplate.Cache.Stampede
  alias PhxBackendBoilerplate.Deadline

  @type freshness :: Entry.freshness()
  @type meta :: %{freshness: freshness()}

  @max_key_bytes 256

  @doc """
  Fetches `key` via SWR.

  `fun` must return `{:ok, value}` or `{:error, reason}`.

  Options:

    * `:soft_ttl` / `:l1_hard_ttl` / `:l2_hard_ttl` — override config (ms)
    * `:lock_ttl` — stampede lock TTL (ms)
    * `:early_refresh_window` — xfetch window (ms)
    * `:now_ms` — inject wall clock (tests)
    * `:telemetry_metadata` — extra span metadata
  """
  def fetch(key, fun, opts \\ [])

  def fetch(key, fun, opts) when is_binary(key) and is_function(fun, 0) and is_list(opts) do
    if byte_size(key) > @max_key_bytes do
      raise ArgumentError, "SWR cache key exceeds #{@max_key_bytes} bytes"
    end

    cfg = config(opts)
    meta = Keyword.get(opts, :telemetry_metadata, %{}) |> Map.put(:key, key)

    :telemetry.span([:phx_backend_boilerplate, :swr, :fetch], meta, fn ->
      fetch_outcome = do_fetch(key, fun, cfg)
      stop_meta = span_meta(fetch_outcome, meta)
      {fetch_outcome, stop_meta}
    end)
  end

  def fetch(key, fun, opts) when is_function(fun, 0) and is_list(opts) do
    raise ArgumentError,
          "SWR cache key must be a string, got: #{inspect(key)}"
  end

  defp do_fetch(key, fun, cfg) do
    now = cfg.now_ms

    case read_entry(key) do
      {:ok, %Entry{value: {:error, _}}} ->
        blocking_miss(key, fun, cfg)

      {:ok, %Entry{} = entry} ->
        case Entry.classify(entry, now) do
          :fresh ->
            maybe_early_refresh(key, fun, entry, cfg)
            {:ok, entry.value, %{freshness: :fresh}}

          :stale ->
            maybe_background_refresh(key, fun, cfg)
            {:ok, entry.value, %{freshness: :stale}}

          :miss ->
            blocking_miss(key, fun, cfg)
        end

      :miss ->
        blocking_miss(key, fun, cfg)
    end
  end

  defp blocking_miss(key, fun, cfg) do
    if Deadline.expired?() do
      {:error, :deadline_exceeded}
    else
      Coalescer.run(key, fn ->
        case Stampede.try_lock(key, cfg.lock_ttl) do
          :acquired ->
            try do
              load_and_store(key, fun, cfg, :miss)
            after
              Stampede.unlock(key)
            end

          :contended ->
            case Stampede.poll_until_value(key) do
              {:ok, %Entry{value: {:error, _}}} ->
                {:error, :deadline_exceeded}

              {:ok, %Entry{} = entry} ->
                # Warm local L1 from polled L2 value.
                _ = L1.put(key, entry, ttl: cfg.l1_hard_ttl)
                {:ok, entry.value, %{freshness: :miss}}

              {:ok, other} ->
                {:ok, other, %{freshness: :miss}}

              {:error, :deadline_exceeded} ->
                {:error, :deadline_exceeded}
            end
        end
      end)
    end
  end

  defp load_and_store(key, fun, cfg, freshness) do
    case fun.() do
      {:ok, value} ->
        entry = Entry.new(value, cfg.soft_ttl, cfg.l2_hard_ttl, cfg.now_ms)
        write_entry(key, entry, cfg)
        {:ok, value, %{freshness: freshness}}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:invalid_loader_result, other}}
    end
  end

  defp maybe_background_refresh(key, fun, cfg) do
    case Regulator.ask(:swr_refresh) do
      :dropped ->
        :ok

      {:ok, ctx} ->
        case Stampede.try_lock(key, cfg.lock_ttl) do
          :acquired ->
            Task.Supervisor.start_child(PhxBackendBoilerplate.Cache.TaskSupervisor, fn ->
              try do
                refresh(key, fun, cfg)
              after
                Regulator.ok(ctx)
              end
            end)

            :ok

          :contended ->
            Regulator.ok(ctx)
            :ok
        end
    end
  end

  defp maybe_early_refresh(key, fun, entry, cfg) do
    remaining = Entry.soft_remaining(entry, cfg.now_ms)
    window = cfg.early_refresh_window

    if window > 0 and remaining > 0 and remaining <= window do
      # Probability increases as soft expiry approaches: 1 - remaining/window
      threshold = 1.0 - remaining / window

      if :rand.uniform() < threshold do
        maybe_background_refresh(key, fun, cfg)
      end
    end

    :ok
  end

  defp refresh(key, fun, cfg) do
    meta = %{key: key}

    :telemetry.span([:phx_backend_boilerplate, :swr, :refresh], meta, fn ->
      refresh_outcome =
        try do
          case fun.() do
            {:ok, value} ->
              entry =
                Entry.new(value, cfg.soft_ttl, cfg.l2_hard_ttl, System.system_time(:millisecond))

              write_entry(key, entry, cfg)
              {:ok, value}

            {:error, reason} ->
              # Stale-if-error: keep previous entry.
              {:error, reason}

            other ->
              {:error, {:invalid_loader_result, other}}
          end
        after
          Stampede.unlock(key)
        end

      {refresh_outcome, Map.put(meta, :result, elem_result(refresh_outcome))}
    end)
  end

  defp elem_result({:ok, _}), do: :ok
  defp elem_result({:error, _}), do: :error

  defp read_entry(key) do
    case Cache.fetch(key) do
      {:ok, %Entry{} = entry} -> {:ok, entry}
      {:ok, _} -> :miss
      {:error, %Nebulex.KeyError{}} -> :miss
      {:error, _} -> :miss
    end
  end

  defp write_entry(key, entry, cfg) do
    # L2 first (source of truth), then L1 with shorter hard TTL.
    :ok = L2.put(key, entry, ttl: cfg.l2_hard_ttl)
    :ok = L1.put(key, entry, ttl: cfg.l1_hard_ttl)
    :ok
  end

  defp config(opts) do
    app = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])

    soft = Keyword.get(opts, :soft_ttl, Keyword.get(app, :soft_ttl, :timer.seconds(30)))
    l1 = Keyword.get(opts, :l1_hard_ttl, Keyword.get(app, :l1_hard_ttl, :timer.minutes(2)))
    l2 = Keyword.get(opts, :l2_hard_ttl, Keyword.get(app, :l2_hard_ttl, :timer.minutes(5)))
    lock = Keyword.get(opts, :lock_ttl, Keyword.get(app, :lock_ttl, 8_000))

    window =
      Keyword.get(opts, :early_refresh_window, Keyword.get(app, :early_refresh_window, 5_000))

    now = Keyword.get(opts, :now_ms, System.system_time(:millisecond))

    if soft >= l1 or l1 >= l2 do
      raise ArgumentError,
            "require soft_ttl < l1_hard_ttl < l2_hard_ttl, got soft=#{soft} l1=#{l1} l2=#{l2}"
    end

    %{
      soft_ttl: soft,
      l1_hard_ttl: l1,
      l2_hard_ttl: l2,
      lock_ttl: lock,
      early_refresh_window: window,
      now_ms: now
    }
  end

  defp span_meta({:ok, _value, %{freshness: freshness}}, meta) do
    Map.merge(meta, %{freshness: freshness})
  end

  defp span_meta({:error, reason}, meta) do
    Map.merge(meta, %{error: reason})
  end

  defp span_meta(_other, meta), do: meta
end
