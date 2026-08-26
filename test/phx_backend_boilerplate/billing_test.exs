defmodule PhxBackendBoilerplate.BillingTest do
  use PhxBackendBoilerplate.DataCase, async: false

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Billing
  alias PhxBackendBoilerplate.Billing.Purchase
  alias PhxBackendBoilerplate.Billing.StripeEvent
  alias PhxBackendBoilerplate.Billing.Subscription
  alias PhxBackendBoilerplate.Integrations.Stripe
  alias PhxBackendBoilerplate.Integrations.Stripe.Fake
  alias PhxBackendBoilerplate.Repo

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

  test "list_plans/0 returns public catalog", _ctx do
    plans = Billing.list_plans()

    assert length(plans) == 2
    assert Enum.any?(plans, &(&1.key == "lifetime" and &1.mode == "payment"))
    assert Enum.any?(plans, &(&1.key == "pro" and &1.mode == "subscription"))
    refute Enum.any?(plans, &Map.has_key?(&1, :price_id))
  end

  test "create_checkout_session/2 for lifetime creates customer and session", %{auth: auth} do
    user = auth.user

    assert {:ok, session} = Billing.create_checkout_session(user, "lifetime")
    assert session.plan == "lifetime"
    assert session.mode == "payment"
    assert is_binary(session.url)
    assert is_binary(session.session_id)

    updated = Accounts.get_user!(user.id)
    assert is_binary(updated.stripe_customer_id)

    assert Enum.any?(Fake.calls(), fn
             {:create_customer, "auth@example.com", opts} ->
               Keyword.get(opts, :idempotency_key) == "customer-#{user.id}"

             _ ->
               false
           end)
  end

  test "create_checkout_session/2 reuses existing stripe customer", %{auth: auth} do
    user = auth.user
    existing_id = "cus_existing_123"

    user
    |> Ecto.Changeset.change(stripe_customer_id: existing_id)
    |> Repo.update!()

    assert {:ok, _session} = Billing.create_checkout_session(user, "lifetime")

    refute Enum.any?(Fake.calls(), fn
             {:create_customer, _, _} -> true
             _ -> false
           end)

    assert Accounts.get_user!(user.id).stripe_customer_id == existing_id
  end

  test "create_checkout_session/2 concurrent checkouts persist one customer id", %{auth: auth} do
    user = auth.user

    tasks =
      for _ <- 1..2 do
        Task.async(fn -> Billing.create_checkout_session(user, "lifetime") end)
      end

    results = Enum.map(tasks, &Task.await/1)
    assert Enum.all?(results, &match?({:ok, _}, &1))

    persisted = Accounts.get_user!(user.id).stripe_customer_id
    assert is_binary(persisted)

    create_calls =
      Fake.calls()
      |> Enum.filter(fn
        {:create_customer, _, _} -> true
        _ -> false
      end)

    assert length(create_calls) == 2

    assert Enum.all?(create_calls, fn
             {:create_customer, "auth@example.com", opts} ->
               Keyword.get(opts, :idempotency_key) == "customer-#{user.id}"

             _ ->
               false
           end)
  end

  test "create_checkout_session/2 for pro subscription", %{auth: auth} do
    assert {:ok, session} = Billing.create_checkout_session(auth.user, "pro")
    assert session.plan == "pro"
    assert session.mode == "subscription"
  end

  test "create_checkout_session/2 rejects invalid plan", %{auth: auth} do
    assert {:error, :invalid_plan} = Billing.create_checkout_session(auth.user, "enterprise")
  end

  test "handle_event/1 records one-time purchase", %{auth: auth} do
    event = checkout_completed_event(auth.user.id, "lifetime", "payment")

    assert :ok = Billing.handle_event(event)
    assert [%Purchase{plan: "lifetime", status: "completed"}] = Repo.all(Purchase)
  end

  test "handle_event/1 upserts subscription", %{auth: auth} do
    event =
      checkout_completed_event(auth.user.id, "pro", "subscription",
        subscription_id: "sub_test_123"
      )

    assert :ok = Billing.handle_event(event)
    assert [%Subscription{plan: "pro", status: "active"}] = Repo.all(Subscription)
  end

  test "handle_event/1 updates existing subscription on customer.subscription.updated", %{
    auth: auth
  } do
    subscription_id = "sub_test_123"

    assert :ok =
             Billing.handle_event(
               checkout_completed_event(auth.user.id, "pro", "subscription",
                 subscription_id: subscription_id,
                 event_id: "evt_checkout_sub"
               )
             )

    update_event = %{
      "id" => "evt_sub_updated",
      "type" => "customer.subscription.updated",
      "data" => %{
        "object" => %{
          "id" => subscription_id,
          "status" => "canceled",
          "current_period_end" => System.system_time(:second) + 86_400,
          "metadata" => %{"user_id" => auth.user.id},
          "items" => %{"data" => [%{"price" => %{"id" => "price_fake_pro"}}]}
        }
      }
    }

    assert :ok = Billing.handle_event(update_event)
    assert [%Subscription{status: "canceled"}] = Repo.all(Subscription)
    assert length(Repo.all(Subscription)) == 1
  end

  test "handle_event/1 is idempotent", %{auth: auth} do
    event =
      checkout_completed_event(auth.user.id, "lifetime", "payment", event_id: "evt_idempotent")

    assert :ok = Billing.handle_event(event)
    assert {:ok, :duplicate} = Billing.handle_event(event)
    assert length(Repo.all(Purchase)) == 1
    assert length(Repo.all(StripeEvent)) == 1
  end

  test "handle_event/1 returns error when purchase user_id is invalid" do
    bad_user_id = Ecto.UUID.generate()
    event = checkout_completed_event(bad_user_id, "lifetime", "payment", event_id: "evt_bad_user")

    assert {:error, %Ecto.Changeset{}} = Billing.handle_event(event)
    assert Repo.all(Purchase) == []
    assert Repo.all(StripeEvent) == []
  end

  test "handle_event/1 returns error when Stripe retrieve fails", %{auth: auth} do
    Fake.stub(:retrieve_subscription, {:error, :timeout})

    event =
      checkout_completed_event(
        auth.user.id,
        "pro",
        "subscription",
        subscription_id: "sub_timeout",
        event_id: "evt_stripe_fail"
      )

    assert {:error, :timeout} = Billing.handle_event(event)
    assert Repo.all(Subscription) == []
    assert Repo.all(StripeEvent) == []
  end

  test "handle_event/1 succeeds on retry after Stripe retrieve failure", %{auth: auth} do
    event =
      checkout_completed_event(
        auth.user.id,
        "pro",
        "subscription",
        subscription_id: "sub_retry",
        event_id: "evt_retry"
      )

    Fake.stub(:retrieve_subscription, {:error, :timeout})
    assert {:error, :timeout} = Billing.handle_event(event)
    assert Repo.all(Subscription) == []
    assert Repo.all(StripeEvent) == []

    Fake.reset()

    assert :ok = Billing.handle_event(event)
    assert [%Subscription{plan: "pro", status: "active"}] = Repo.all(Subscription)
    assert length(Repo.all(StripeEvent)) == 1
  end

  test "get_status/0 returns purchases and subscription", %{auth: auth} do
    :ok = Billing.handle_event(checkout_completed_event(auth.user.id, "lifetime", "payment"))

    :ok =
      Billing.handle_event(
        checkout_completed_event(auth.user.id, "pro", "subscription", subscription_id: "sub_1")
      )

    status = Billing.get_status(auth.user)

    assert length(status.purchases) == 1
    assert status.subscription.plan == "pro"
  end

  test "get_status/1 caps purchase history", %{auth: auth} do
    max = Billing.max_status_purchases()

    for i <- 1..(max + 3) do
      %Purchase{}
      |> Purchase.changeset(%{
        user_id: auth.user.id,
        plan: "lifetime",
        stripe_checkout_session_id: "cs_cap_#{i}_#{System.unique_integer([:positive])}",
        status: "completed"
      })
      |> Repo.insert!()
    end

    status = Billing.get_status(auth.user)
    assert length(status.purchases) == max
  end

  defp register_attrs do
    %{"email" => "auth@example.com", "password" => "password123"}
  end

  defp checkout_completed_event(user_id, plan, mode, opts \\ []) do
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
