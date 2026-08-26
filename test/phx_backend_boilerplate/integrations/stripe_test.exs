defmodule PhxBackendBoilerplate.Integrations.StripeTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Integrations.Stripe
  alias PhxBackendBoilerplate.Integrations.Stripe.Fake

  setup do
    previous = Application.get_env(:phx_backend_boilerplate, Stripe, [])
    Fake.reset()

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Stripe, previous)
    end)

    Application.put_env(:phx_backend_boilerplate, Stripe,
      skip: false,
      adapter: Fake,
      secret_key: "sk_test_fake",
      webhook_secret: "whsec_test_fake"
    )

    :ok
  end

  test "create_customer/1 returns fake customer" do
    assert {:ok, %{"id" => id, "email" => "buyer@example.com"}} =
             Stripe.create_customer("buyer@example.com")

    assert is_binary(id)
    assert [{:create_customer, "buyer@example.com", _opts}] = Fake.calls()
  end

  test "create_customer/2 forwards idempotency key" do
    assert {:ok, %{"id" => _id}} =
             Stripe.create_customer("buyer@example.com", idempotency_key: "customer-user-id")

    assert [{:create_customer, "buyer@example.com", opts}] = Fake.calls()
    assert Keyword.get(opts, :idempotency_key) == "customer-user-id"
  end

  test "create_checkout_session/2 records params" do
    params = %{
      "mode" => "payment",
      "customer" => "cus_123",
      "line_items" => [%{"price" => "price_lifetime", "quantity" => 1}]
    }

    assert {:ok, %{"url" => url, "id" => session_id}} =
             Stripe.create_checkout_session(params, idempotency_key: "checkout-user-plan")

    assert is_binary(url)
    assert is_binary(session_id)
    assert [{:create_checkout_session, ^params, opts}] = Fake.calls()
    assert Keyword.get(opts, :idempotency_key) == "checkout-user-plan"
  end

  test "returns skipped when skip is true" do
    Application.put_env(:phx_backend_boilerplate, Stripe, skip: true, secret_key: "sk_test")

    assert {:error, :skipped} = Stripe.create_customer("buyer@example.com")
  end

  test "returns misconfigured without secret key" do
    Application.put_env(:phx_backend_boilerplate, Stripe, skip: false, secret_key: nil)

    assert {:error, :misconfigured} = Stripe.create_customer("buyer@example.com")
  end
end
