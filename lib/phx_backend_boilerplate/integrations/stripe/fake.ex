defmodule PhxBackendBoilerplate.Integrations.Stripe.Fake do
  @moduledoc """
  Test double for Stripe API calls.

  Records calls and returns configurable responses. Defaults to successful
  customer and checkout session payloads.
  """

  @doc false
  def create_customer(email, opts) when is_binary(email) and is_list(opts) do
    record_call({:create_customer, email, opts})
    result(:create_customer, default_customer(email))
  end

  @doc false
  def create_checkout_session(params, opts) when is_map(params) and is_list(opts) do
    record_call({:create_checkout_session, params, opts})

    result(
      :create_checkout_session,
      default_checkout_session(params)
    )
  end

  @doc false
  def retrieve_subscription(subscription_id, opts)
      when is_binary(subscription_id) and is_list(opts) do
    record_call({:retrieve_subscription, subscription_id, opts})

    result(
      :retrieve_subscription,
      default_subscription(subscription_id)
    )
  end

  @doc false
  def retrieve_event(event_id, opts) when is_binary(event_id) and is_list(opts) do
    record_call({:retrieve_event, event_id, opts})

    cfg = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    results = Keyword.get(cfg, :results, %{})

    case Map.get(results, :retrieve_event) do
      nil ->
        events = Keyword.get(cfg, :events, %{})

        case Map.get(events, event_id) do
          nil -> {:error, :not_found}
          event -> {:ok, event}
        end

      stubbed_outcome ->
        stubbed_outcome
    end
  end

  @doc """
  Registers a Stripe event payload for `retrieve_event/2` (test helper).
  """
  def put_event(%{"id" => event_id} = event) when is_binary(event_id) do
    cfg = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    events = Keyword.get(cfg, :events, %{})

    Application.put_env(
      :phx_backend_boilerplate,
      __MODULE__,
      Keyword.put(cfg, :events, Map.put(events, event_id, event))
    )

    :ok
  end

  @doc """
  Returns recorded API calls (test helper).
  """
  def calls do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:calls, [])
  end

  @doc """
  Clears recorded calls and optional result overrides.
  """
  def reset do
    Application.put_env(:phx_backend_boilerplate, __MODULE__, [])
  end

  @doc """
  Configures a result override for a specific API operation (test helper).

      Fake.stub(:retrieve_subscription, {:error, :timeout})
  """
  def stub(operation, outcome) when is_atom(operation) do
    cfg = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    results = Keyword.get(cfg, :results, %{})

    Application.put_env(
      :phx_backend_boilerplate,
      __MODULE__,
      Keyword.put(cfg, :results, Map.put(results, operation, outcome))
    )
  end

  defp record_call(call) do
    cfg = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    calls = Keyword.get(cfg, :calls, [])

    Application.put_env(
      :phx_backend_boilerplate,
      __MODULE__,
      Keyword.put(cfg, :calls, calls ++ [call])
    )
  end

  defp result(key, default) do
    cfg = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    results = Keyword.get(cfg, :results, %{})
    Map.get(results, key, Keyword.get(cfg, :result, {:ok, default}))
  end

  defp default_customer(email) do
    %{
      "id" => "cus_fake_#{Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)}",
      "email" => email,
      "object" => "customer"
    }
  end

  defp default_checkout_session(params) do
    session_id = "cs_test_fake_#{Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)}"

    %{
      "id" => session_id,
      "object" => "checkout.session",
      "url" => "https://checkout.stripe.test/pay/#{session_id}",
      "mode" => Map.get(params, "mode", "payment"),
      "customer" => Map.get(params, "customer"),
      "metadata" => Map.get(params, "metadata", %{})
    }
  end

  defp default_subscription(subscription_id) do
    now = System.system_time(:second)

    %{
      "id" => subscription_id,
      "object" => "subscription",
      "status" => "active",
      "current_period_end" => now + 2_592_000,
      "items" => %{
        "data" => [
          %{
            "price" => %{
              "id" => "price_fake_pro"
            }
          }
        ]
      }
    }
  end
end
