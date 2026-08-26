defmodule PhxBackendBoilerplateWeb.Demo.CachedController do
  @moduledoc """
  Demo endpoint for SWR caching with coalescing and stampede protection.

  Query params:

    * `key` — cache key (default `"demo"`)
    * `work_ms` — simulated loader work, capped at 2000ms
    * `error` — when `"1"`, loader returns an error (demo only)
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.SWR

  @max_work_ms 2_000
  @max_key_bytes 64
  @key_prefix "demo:cached:"
  @demo_soft_ttl 2_000
  @demo_l1_hard_ttl 5_000
  @demo_l2_hard_ttl 15_000

  def show(conn, params) do
    work_ms = parse_work_ms(params)
    simulate_error? = Map.get(params, "error") in ["1", 1]

    case cache_key(params) do
      {:ok, user_key, storage_key} ->
        fetch_cached(conn, user_key, storage_key, work_ms, simulate_error?)

      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: %{detail: "Invalid cache key"}})
    end
  end

  defp fetch_cached(conn, user_key, storage_key, work_ms, simulate_error?) do
    case SWR.fetch(
           storage_key,
           fn ->
             cond do
               simulate_error? ->
                 {:error, {:l2, :econnrefused}}

               work_ms > 0 ->
                 Process.sleep(work_ms)

                 {:ok,
                  %{
                    "key" => user_key,
                    "computed_at" => System.system_time(:millisecond),
                    "work_ms" => work_ms
                  }}

               true ->
                 {:ok,
                  %{
                    "key" => user_key,
                    "computed_at" => System.system_time(:millisecond),
                    "work_ms" => work_ms
                  }}
             end
           end,
           soft_ttl: @demo_soft_ttl,
           l1_hard_ttl: @demo_l1_hard_ttl,
           l2_hard_ttl: @demo_l2_hard_ttl
         ) do
      {:ok, value, %{freshness: freshness}} ->
        json(conn, %{data: value, freshness: freshness})

      {:error, :deadline_exceeded} ->
        conn
        |> put_status(:gateway_timeout)
        |> json(%{errors: %{detail: "Gateway Timeout"}})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: %{detail: "Internal Server Error"}})
    end
  end

  defp parse_work_ms(params) do
    raw = Map.get(params, "work_ms") || Map.get(params, :work_ms)

    case Integer.parse(to_string(raw || "0")) do
      {n, _} when n > 0 -> min(n, @max_work_ms)
      _ -> 0
    end
  end

  defp cache_key(params) do
    user_key = params |> Map.get("key", "demo") |> to_string()

    if valid_user_key?(user_key) do
      {:ok, user_key, @key_prefix <> user_key}
    else
      :error
    end
  end

  defp valid_user_key?(key)
       when is_binary(key) and byte_size(key) > 0 and byte_size(key) <= @max_key_bytes do
    Regex.match?(~r/^[A-Za-z0-9._-]+$/, key)
  end

  defp valid_user_key?(_), do: false
end
