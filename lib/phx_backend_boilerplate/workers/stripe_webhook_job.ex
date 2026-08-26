defmodule PhxBackendBoilerplate.Workers.StripeWebhookJob do
  @moduledoc """
  Processes Stripe webhook events asynchronously.

  Args:

    * `"stripe_event_id"` (required) — Stripe event id for idempotency
    * `"event"` (required) — full Stripe event payload map
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [fields: [:args], keys: [:stripe_event_id], period: 86_400]

  alias PhxBackendBoilerplate.Billing

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => event}}) do
    case Billing.handle_event(event) do
      :ok -> :ok
      {:ok, :duplicate} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def perform(%Oban.Job{args: args}) do
    if Map.has_key?(args, "stripe_event_id") do
      {:error, :missing_event}
    else
      {:error, :missing_event}
    end
  end
end
