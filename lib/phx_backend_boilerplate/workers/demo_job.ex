defmodule PhxBackendBoilerplate.Workers.DemoJob do
  @moduledoc """
  Example Oban worker for the demo jobs API.

  Args:

    * `"message"` (required) — logged payload
    * `"work_ms"` (optional) — simulated work, capped at 2000ms
    * `"request_id"` / `"correlation_id"` (optional) — tracing from the enqueueing request
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias PhxBackendBoilerplate.RequestContext

  @max_work_ms 2_000

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    message = Map.get(args, "message")

    if is_binary(message) and message != "" do
      ctx = %{
        request_id: Map.get(args, "request_id"),
        correlation_id: Map.get(args, "correlation_id"),
        user_id: nil
      }

      RequestContext.with(ctx, fn ->
        work_ms = parse_work_ms(Map.get(args, "work_ms"))
        if work_ms > 0, do: Process.sleep(work_ms)

        Logger.info("demo job completed message=#{inspect(message)} work_ms=#{work_ms}")
        :ok
      end)
    else
      {:error, :missing_message}
    end
  end

  defp parse_work_ms(raw) when is_integer(raw) and raw > 0, do: min(raw, @max_work_ms)

  defp parse_work_ms(raw) when is_binary(raw) do
    case Integer.parse(raw) do
      {n, _} when n > 0 -> min(n, @max_work_ms)
      _ -> 0
    end
  end

  defp parse_work_ms(_), do: 0
end
