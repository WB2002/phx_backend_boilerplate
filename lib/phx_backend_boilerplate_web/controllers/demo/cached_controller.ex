defmodule PhxBackendBoilerplateWeb.Demo.CachedController do
  @moduledoc """
  Demo endpoint for SWR caching with coalescing and stampede protection.

  Query params:

    * `key` — cache key (default `"demo"`)
    * `work_ms` — simulated loader work, capped at 2000ms
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.SWR

  @max_work_ms 2_000
  @demo_soft_ttl 2_000
  @demo_l1_hard_ttl 5_000
  @demo_l2_hard_ttl 15_000

  def show(conn, params) do
    key = params |> Map.get("key", "demo") |> to_string()
    work_ms = parse_work_ms(params)

    case SWR.fetch(
           key,
           fn ->
             if work_ms > 0, do: Process.sleep(work_ms)

             {:ok,
              %{
                "key" => key,
                "computed_at" => System.system_time(:millisecond),
                "work_ms" => work_ms
              }}
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

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: %{detail: inspect(reason)}})
    end
  end

  defp parse_work_ms(params) do
    raw = Map.get(params, "work_ms") || Map.get(params, :work_ms)

    case Integer.parse(to_string(raw || "0")) do
      {n, _} when n > 0 -> min(n, @max_work_ms)
      _ -> 0
    end
  end
end
