defmodule PhxBackendBoilerplate.Workers.StripeWebhookJobTest do
  use PhxBackendBoilerplate.DataCase, async: false
  use Oban.Testing, repo: PhxBackendBoilerplate.Repo

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Billing.Purchase
  alias PhxBackendBoilerplate.Billing.StripeEvent
  alias PhxBackendBoilerplate.Billing.Subscription
  alias PhxBackendBoilerplate.Integrations.Stripe
  alias PhxBackendBoilerplate.Integrations.Stripe.Fake
  alias PhxBackendBoilerplate.Repo
  alias PhxBackendBoilerplate.Workers.StripeWebhookJob

  setup do
    previous = Application.get_env(:phx_backend_boilerplate, Stripe, [])
    Fake.reset()

    Application.put_env(:phx_backend_boilerplate, Stripe,
      skip: false,
      adapter: Fake,
      secret_key: "sk_test_fake",
      webhook_secret: "whsec_test_fake"
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Stripe, previous)
    end)

    {:ok, auth} = Accounts.register(register_attrs())
    {:ok, auth: auth}
  end

  test "perform_job records purchase", %{auth: auth} do
    event = checkout_event(auth.user.id, "lifetime", "payment", event_id: "evt_job_purchase")
    :ok = Fake.put_event(event)

    assert :ok = perform_job(StripeWebhookJob, %{"stripe_event_id" => event["id"]})

    assert [%Purchase{plan: "lifetime"}] = Repo.all(Purchase)
    assert length(Repo.all(StripeEvent)) == 1
  end

  test "perform_job duplicate is ok", %{auth: auth} do
    event = checkout_event(auth.user.id, "lifetime", "payment", event_id: "evt_job_dup")
    :ok = Fake.put_event(event)
    args = %{"stripe_event_id" => event["id"]}

    assert :ok = perform_job(StripeWebhookJob, args)
    assert :ok = perform_job(StripeWebhookJob, args)
    assert length(Repo.all(Purchase)) == 1
    assert length(Repo.all(StripeEvent)) == 1
  end

  test "perform_job returns error on entitlement failure" do
    bad_user_id = Ecto.UUID.generate()
    event = checkout_event(bad_user_id, "lifetime", "payment", event_id: "evt_job_bad_user")
    :ok = Fake.put_event(event)

    assert {:error, %Ecto.Changeset{}} =
             perform_job(StripeWebhookJob, %{"stripe_event_id" => event["id"]})

    assert Repo.all(Purchase) == []
    assert Repo.all(StripeEvent) == []
  end

  test "perform_job returns error on Stripe retrieve failure", %{auth: auth} do
    event =
      checkout_event(
        auth.user.id,
        "pro",
        "subscription",
        subscription_id: "sub_job_timeout",
        event_id: "evt_job_stripe_fail"
      )

    :ok = Fake.put_event(event)
    Fake.stub(:retrieve_subscription, {:error, :timeout})

    assert {:error, :timeout} =
             perform_job(StripeWebhookJob, %{"stripe_event_id" => event["id"]})

    assert Repo.all(Subscription) == []
    assert Repo.all(StripeEvent) == []
  end

  test "perform_job succeeds on retry after Stripe retrieve failure", %{auth: auth} do
    event =
      checkout_event(
        auth.user.id,
        "pro",
        "subscription",
        subscription_id: "sub_job_retry",
        event_id: "evt_job_retry"
      )

    args = %{"stripe_event_id" => event["id"]}

    :ok = Fake.put_event(event)
    Fake.stub(:retrieve_subscription, {:error, :timeout})
    assert {:error, :timeout} = perform_job(StripeWebhookJob, args)
    assert Repo.all(Subscription) == []
    assert Repo.all(StripeEvent) == []

    Fake.reset()

    Application.put_env(:phx_backend_boilerplate, Stripe,
      skip: false,
      adapter: Fake,
      secret_key: "sk_test_fake",
      webhook_secret: "whsec_test_fake"
    )

    :ok = Fake.put_event(event)

    assert :ok = perform_job(StripeWebhookJob, args)
    assert [%Subscription{plan: "pro", status: "active"}] = Repo.all(Subscription)
    assert length(Repo.all(StripeEvent)) == 1
  end

  test "perform_job errors when event is not found" do
    assert {:error, :not_found} =
             perform_job(StripeWebhookJob, %{"stripe_event_id" => "evt_missing_payload"})
  end

  test "perform_job errors without stripe_event_id" do
    assert {:error, :missing_stripe_event_id} = perform_job(StripeWebhookJob, %{})
  end

  defp register_attrs do
    %{"email" => "auth@example.com", "password" => "password123"}
  end

  defp checkout_event(user_id, plan, mode, opts) do
    event_id = Keyword.get(opts, :event_id, "evt_#{plan}_#{System.unique_integer()}")
    subscription_id = Keyword.get(opts, :subscription_id)

    session = %{
      "id" => "cs_test_#{plan}",
      "mode" => mode,
      "payment_intent" => "pi_test_#{plan}",
      "client_reference_id" => user_id,
      "metadata" => %{"user_id" => user_id, "plan" => plan},
      "subscription" => subscription_id
    }

    %{
      "id" => event_id,
      "type" => "checkout.session.completed",
      "data" => %{"object" => session}
    }
  end
end
