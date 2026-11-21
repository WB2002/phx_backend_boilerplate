defmodule PhxBackendBoilerplate.Workers.StripeWebhookJob do
  @moduledoc """
  Processes Stripe webhook events asynchronously.

  Args:

    * `"stripe_event_id"` (required) — Stripe event id for idempotency and fetch
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [fields: [:args], keys: [:stripe_event_id], period: 86_400]

  alias PhxBackendBoilerplate.Billing
  alias PhxBackendBoilerplate.Integrations.Stripe

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"stripe_event_id" => event_id}}) when is_binary(event_id) do
    with {:ok, event} <- Stripe.retrieve_event(event_id),
         handling_outcome <- Billing.handle_event(event) do
      case handling_outcome do
        :ok -> :ok
        {:ok, :duplicate} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def perform(%Oban.Job{}), do: {:error, :missing_stripe_event_id}
end
