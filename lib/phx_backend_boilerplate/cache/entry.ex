defmodule PhxBackendBoilerplate.Cache.Entry do
  @moduledoc """
  Cached payload wrapper with soft TTL metadata.

  Soft TTL is application-level (SWR). Hard TTL is applied via Nebulex `:ttl`
  on put (L1 shorter than L2). `inserted_at_ms` uses wall clock so entries
  are comparable across nodes; soft TTL is approximate under clock skew.
  """

  @enforce_keys [:value, :inserted_at_ms, :soft_ttl_ms, :hard_ttl_ms]
  defstruct [:value, :inserted_at_ms, :soft_ttl_ms, :hard_ttl_ms]

  @type t :: %__MODULE__{
          value: term(),
          inserted_at_ms: integer(),
          soft_ttl_ms: pos_integer(),
          hard_ttl_ms: pos_integer()
        }

  @type freshness :: :fresh | :stale | :miss

  @doc """
  Builds an entry. `hard_ttl_ms` should be the L2 hard TTL (source of truth).
  """
  def new(value, soft_ttl_ms, hard_ttl_ms, now_ms \\ System.system_time(:millisecond))
      when is_integer(soft_ttl_ms) and soft_ttl_ms > 0 and is_integer(hard_ttl_ms) and
             hard_ttl_ms > soft_ttl_ms do
    %__MODULE__{
      value: value,
      inserted_at_ms: now_ms,
      soft_ttl_ms: soft_ttl_ms,
      hard_ttl_ms: hard_ttl_ms
    }
  end

  @doc """
  Classifies an entry (or absence / poisoned value) at `now_ms`.

  Past Nebulex hard expiry the key is usually gone (`:miss`). If still present
  past soft TTL → `:stale`. Poisoned `%{value: {:error, _}}` → `:miss`.
  """
  def classify(nil, _now_ms), do: :miss

  def classify(%__MODULE__{value: {:error, _}}, _now_ms), do: :miss

  def classify(%__MODULE__{} = entry, now_ms) when is_integer(now_ms) do
    age = now_ms - entry.inserted_at_ms

    cond do
      age < 0 ->
        # Clock skew: treat as fresh rather than immediately stale.
        :fresh

      age < entry.soft_ttl_ms ->
        :fresh

      age < entry.hard_ttl_ms ->
        :stale

      true ->
        :miss
    end
  end

  def classify(_other, _now_ms), do: :miss

  @doc """
  Milliseconds remaining until soft TTL, or `0` if already soft-expired.
  """
  def soft_remaining(%__MODULE__{} = entry, now_ms) when is_integer(now_ms) do
    max(entry.inserted_at_ms + entry.soft_ttl_ms - now_ms, 0)
  end
end
