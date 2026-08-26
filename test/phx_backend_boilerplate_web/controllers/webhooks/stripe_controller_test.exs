defmodule PhxBackendBoilerplateWeb.Webhooks.StripeControllerTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false
  use Oban.Testing, repo: PhxBackendBoilerplate.Repo

  alias PhxBackendBoilerplate.Integrations.Stripe
  alias PhxBackendBoilerplate.Workers.StripeWebhookJob

  @secret "whsec_test_fake"
  @payload ~s({"id":"evt_test_webhook","type":"checkout.session.completed","data":{"object":{"id":"cs_test"}}})

  setup do
    :ok = PhxBackendBoilerplate.Test.RateLimitHelpers.clear_id("stripe_webhook")

    previous = Application.get_env(:phx_backend_boilerplate, Stripe, [])

    Application.put_env(:phx_backend_boilerplate, Stripe,
      skip: false,
      webhook_secret: @secret
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Stripe, previous)
    end)

    :ok
  end

  test "POST /api/webhooks/stripe rejects missing signature", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(~p"/api/webhooks/stripe", @payload)

    assert json_response(conn, 400)["errors"]["detail"] == "Missing Stripe-Signature"
  end

  test "POST /api/webhooks/stripe rejects invalid signature", %{conn: conn} do
    timestamp = System.system_time(:second)
    header = "t=#{timestamp},v1=deadbeef"

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", header)
      |> post(~p"/api/webhooks/stripe", @payload)

    assert json_response(conn, 400)["errors"]["detail"] == "Invalid signature"
  end

  test "POST /api/webhooks/stripe enqueues job on valid signature", %{conn: conn} do
    header = sign(@payload, @secret)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("stripe-signature", header)
      |> post(~p"/api/webhooks/stripe", @payload)

    assert response(conn, 200) == ""

    assert_enqueued(
      worker: StripeWebhookJob,
      args: %{"stripe_event_id" => "evt_test_webhook"}
    )

    [job | _] = all_enqueued(worker: StripeWebhookJob)
    refute Map.has_key?(job.args, "event")
  end

  defp sign(payload, secret) do
    timestamp = System.system_time(:second)

    signature =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{payload}")
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{signature}"
  end
end
