defmodule PhxBackendBoilerplate.Workers.DemoJob do
  @moduledoc """
  Example Oban worker for the demo jobs API.

  Args:

    * `"message"` (required) — logged payload
    * `"work_ms"` (optional) — simulated work, capped at 2000ms
    * `"notify_slack"` (optional) — when true, posts to Slack after completion
    * `"slack_channel"` (optional) — channel for Slack notify (or config default)
    * `"request_id"` / `"correlation_id"` (optional) — tracing from the enqueueing request
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [
      period: 60,
      fields: [:worker, :args],
      keys: [:message],
      states: [:available, :scheduled, :executing, :retryable]
    ]

  require Logger

  alias PhxBackendBoilerplate.Integrations.Slack
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
        maybe_notify_slack(args, message)
        :ok
      end)
    else
      {:error, :missing_message}
    end
  end

  defp maybe_notify_slack(args, message) do
    if notify_slack?(args) do
      opts =
        case Map.get(args, "slack_channel") do
          channel when is_binary(channel) and channel != "" -> [channel: channel]
          _ -> []
        end

      case Slack.notify("Demo job completed: #{message}", opts) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("slack notify failed reason=#{inspect(reason)}")
          :ok
      end
    end
  end

  defp notify_slack?(args) do
    case Map.get(args, "notify_slack") do
      true -> true
      "true" -> true
      "1" -> true
      _ -> false
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
