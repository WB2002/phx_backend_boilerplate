defmodule PhxBackendBoilerplateWeb.Webhooks.StripeController do
  @moduledoc """
  Stripe webhook receiver.

  Verifies `Stripe-Signature`, enqueues async processing, and returns 200 quickly.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.Integrations.Stripe
  alias PhxBackendBoilerplate.Integrations.Stripe.Signature
  alias PhxBackendBoilerplate.Jobs

  def create(conn, _params) do
    payload = conn.assigns[:raw_body] || ""

    with {:ok, secret} <- Stripe.webhook_secret(),
         :ok <- Signature.verify(payload, stripe_signature(conn), secret: secret),
         {:ok, event} <- Jason.decode(payload),
         {:ok, _job} <- Jobs.enqueue_stripe_webhook(event["id"]) do
      send_resp(conn, :ok, "")
    else
      {:error, :missing_header} ->
        conn |> put_status(:bad_request) |> json(%{errors: %{detail: "Missing Stripe-Signature"}})

      {:error, :invalid_signature} ->
        conn |> put_status(:bad_request) |> json(%{errors: %{detail: "Invalid signature"}})

      {:error, :timestamp_out_of_tolerance} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: %{detail: "Timestamp out of tolerance"}})

      {:error, _} ->
        conn |> put_status(:bad_request) |> json(%{errors: %{detail: "Invalid webhook"}})
    end
  end

  defp stripe_signature(conn) do
    case get_req_header(conn, "stripe-signature") do
      [header | _] -> header
      _ -> nil
    end
  end
end
