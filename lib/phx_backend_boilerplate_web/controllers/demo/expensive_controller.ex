defmodule PhxBackendBoilerplateWeb.Demo.ExpensiveController do
  @moduledoc """
  Demo endpoint protected by Hammer (rate limit) then Regulator (load shed).

  Optional query param `hold_ms` (capped) sleeps while holding a concurrency
  token so parallel clients can observe `503` when the Static limit is full.
  """

  use PhxBackendBoilerplateWeb, :controller

  @max_hold_ms 5_000

  def show(conn, params) do
    hold_ms = parse_hold_ms(params)

    if hold_ms > 0 do
      Process.sleep(hold_ms)
    end

    json(conn, %{
      data: %{
        message: "Expensive demo",
        hold_ms: hold_ms
      }
    })
  end

  defp parse_hold_ms(params) do
    raw = Map.get(params, "hold_ms") || Map.get(params, :hold_ms)

    case Integer.parse(to_string(raw || "0")) do
      {n, _} when n > 0 -> min(n, @max_hold_ms)
      _ -> 0
    end
  end
end
