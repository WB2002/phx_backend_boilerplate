defmodule PhxBackendBoilerplate.Billing do
  @moduledoc """
  Stripe Checkout billing: plan catalog, session creation, and webhook-driven
  entitlement updates.
  """

  import Ecto.Query, warn: false

  alias PhxBackendBoilerplate.Accounts.User
  alias PhxBackendBoilerplate.Billing.Purchase
  alias PhxBackendBoilerplate.Billing.StripeEvent
  alias PhxBackendBoilerplate.Billing.Subscription
  alias PhxBackendBoilerplate.Integrations.Stripe
  alias PhxBackendBoilerplate.Repo

  @doc """
  Returns the public plan catalog (no secret keys).
  """
  @spec list_plans() :: [map()]
  def list_plans do
    plans()
    |> Map.values()
    |> Enum.map(&public_plan/1)
    |> Enum.sort_by(& &1.key)
  end

  @doc """
  Creates a Stripe Checkout Session for the given user and plan key.

  Returns `{:ok, session}` with `url`, `session_id`, `plan`, and `mode`.
  """
  @spec create_checkout_session(User.t(), String.t()) ::
          {:ok, map()} | {:error, atom() | Ecto.Changeset.t() | term()}
  def create_checkout_session(%User{} = user, plan_key) when is_binary(plan_key) do
    with {:ok, plan} <- fetch_plan(plan_key),
         {:ok, customer_id} <- ensure_stripe_customer(user),
         params <- checkout_session_params(user, plan, customer_id),
         idempotency_key <- checkout_idempotency_key(user.id, plan_key),
         {:ok, session} <-
           Stripe.create_checkout_session(params, idempotency_key: idempotency_key) do
      {:ok,
       %{
         url: session["url"],
         session_id: session["id"],
         plan: plan_key,
         mode: plan.mode
       }}
    end
  end

  @doc """
  Returns local billing status for a user (purchases and active subscription).
  """
  @spec get_status(User.t()) :: map()
  def get_status(%User{id: user_id}) do
    purchases =
      Purchase
      |> where([p], p.user_id == ^user_id)
      |> order_by([p], desc: p.inserted_at)
      |> Repo.all()
      |> Enum.map(&purchase_payload/1)

    subscription =
      Subscription
      |> where([s], s.user_id == ^user_id)
      |> order_by([s], desc: s.inserted_at)
      |> limit(1)
      |> Repo.one()
      |> subscription_payload()

    %{
      purchases: purchases,
      subscription: subscription
    }
  end

  @doc """
  Records a Stripe webhook event idempotently and applies side effects.

  Returns `:ok`, `{:ok, :duplicate}`, or `{:error, reason}`.
  """
  @spec handle_event(map()) :: :ok | {:ok, :duplicate} | {:error, term()}
  def handle_event(%{"id" => event_id, "type" => type} = event)
      when is_binary(event_id) and is_binary(type) do
    case insert_stripe_event(event_id, type) do
      {:ok, _} ->
        apply_event(event)
        :ok

      {:error, %Ecto.Changeset{errors: errors}} ->
        if duplicate_event?(errors) do
          {:ok, :duplicate}
        else
          {:error, :invalid_event}
        end
    end
  end

  def handle_event(_), do: {:error, :invalid_event}

  defp insert_stripe_event(event_id, type) do
    %StripeEvent{}
    |> StripeEvent.changeset(%{stripe_event_id: event_id, event_type: type})
    |> Repo.insert()
  end

  defp duplicate_event?(errors) do
    Enum.any?(errors, fn
      {:stripe_event_id, {_msg, opts}} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end

  defp apply_event(%{"type" => "checkout.session.completed", "data" => %{"object" => session}}) do
    case session["mode"] do
      "payment" -> insert_purchase_from_session(session)
      "subscription" -> upsert_subscription_from_session(session)
      _ -> :ok
    end
  end

  defp apply_event(%{"type" => type, "data" => %{"object" => subscription}})
       when type in ["customer.subscription.updated", "customer.subscription.deleted"] do
    upsert_subscription_from_stripe(subscription)
  end

  defp apply_event(_), do: :ok

  defp insert_purchase_from_session(session) do
    user_id = session_user_id(session)
    session_id = session["id"]

    if user_id && session_id do
      attrs = %{
        user_id: user_id,
        plan: session["metadata"]["plan"] || "lifetime",
        stripe_checkout_session_id: session_id,
        stripe_payment_intent_id: session["payment_intent"],
        status: "completed"
      }

      %Purchase{}
      |> Purchase.changeset(attrs)
      |> Repo.insert(on_conflict: :nothing, conflict_target: :stripe_checkout_session_id)
      |> case do
        {:ok, _} -> :ok
        {:error, _} -> :ok
      end
    else
      :ok
    end
  end

  defp upsert_subscription_from_session(session) do
    case session["subscription"] do
      subscription_id when is_binary(subscription_id) ->
        with {:ok, subscription} <- Stripe.retrieve_subscription(subscription_id) do
          upsert_subscription_from_stripe(subscription, session)
        else
          _ -> :ok
        end

      _ ->
        :ok
    end
  end

  defp upsert_subscription_from_stripe(subscription, checkout_session \\ nil) do
    user_id =
      case checkout_session do
        %{"metadata" => %{"user_id" => id}} when is_binary(id) -> id
        _ -> subscription_user_id(subscription)
      end

    subscription_id = subscription["id"]

    if user_id && subscription_id do
      plan =
        case checkout_session do
          %{"metadata" => %{"plan" => plan}} when is_binary(plan) -> plan
          _ -> "pro"
        end

      attrs = %{
        user_id: user_id,
        plan: plan,
        stripe_subscription_id: subscription_id,
        stripe_price_id: subscription_price_id(subscription),
        status: subscription["status"],
        current_period_end: unix_to_datetime(subscription["current_period_end"])
      }

      case Repo.get_by(Subscription, stripe_subscription_id: subscription_id) do
        nil ->
          %Subscription{}
          |> Subscription.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> Subscription.changeset(attrs)
          |> Repo.update()
      end
      |> case do
        {:ok, _} -> :ok
        {:error, _} -> :ok
      end
    else
      :ok
    end
  end

  defp ensure_stripe_customer(%User{stripe_customer_id: id}) when is_binary(id) and id != "" do
    {:ok, id}
  end

  defp ensure_stripe_customer(%User{} = user) do
    with {:ok, customer} <- Stripe.create_customer(user.email),
         {:ok, updated} <- persist_stripe_customer_id(user, customer["id"]) do
      {:ok, updated.stripe_customer_id}
    end
  end

  defp persist_stripe_customer_id(%User{} = user, customer_id) do
    user
    |> Ecto.Changeset.change(stripe_customer_id: customer_id)
    |> Repo.update()
  end

  defp checkout_session_params(%User{} = user, plan, customer_id) do
    %{
      "customer" => customer_id,
      "client_reference_id" => user.id,
      "mode" => plan.mode,
      "success_url" => success_url(),
      "cancel_url" => cancel_url(),
      "metadata" => %{
        "user_id" => user.id,
        "plan" => plan.key
      },
      "line_items" => [
        %{
          "price" => plan.price_id,
          "quantity" => 1
        }
      ]
    }
  end

  defp checkout_idempotency_key(user_id, plan_key), do: "checkout-#{user_id}-#{plan_key}"

  defp fetch_plan(plan_key) do
    case Map.get(plans(), plan_key) do
      nil -> {:error, :invalid_plan}
      plan -> {:ok, plan}
    end
  end

  defp public_plan(plan) do
    %{
      key: plan.key,
      name: plan.name,
      description: plan.description,
      mode: plan.mode
    }
  end

  defp purchase_payload(%Purchase{} = purchase) do
    %{
      id: purchase.id,
      plan: purchase.plan,
      status: purchase.status,
      stripe_checkout_session_id: purchase.stripe_checkout_session_id,
      inserted_at: purchase.inserted_at
    }
  end

  defp subscription_payload(nil), do: nil

  defp subscription_payload(%Subscription{} = subscription) do
    %{
      id: subscription.id,
      plan: subscription.plan,
      status: subscription.status,
      stripe_subscription_id: subscription.stripe_subscription_id,
      stripe_price_id: subscription.stripe_price_id,
      current_period_end: subscription.current_period_end,
      inserted_at: subscription.inserted_at,
      updated_at: subscription.updated_at
    }
  end

  defp session_user_id(%{"metadata" => %{"user_id" => id}}) when is_binary(id), do: id
  defp session_user_id(%{"client_reference_id" => id}) when is_binary(id), do: id
  defp session_user_id(_), do: nil

  defp subscription_user_id(%{"metadata" => %{"user_id" => id}}) when is_binary(id), do: id
  defp subscription_user_id(_), do: nil

  defp subscription_price_id(%{"items" => %{"data" => [%{"price" => %{"id" => id}} | _]}}), do: id
  defp subscription_price_id(_), do: "unknown"

  defp unix_to_datetime(nil), do: nil

  defp unix_to_datetime(unix) when is_integer(unix) do
    DateTime.from_unix!(unix, :second)
  end

  defp plans do
    billing_config()
    |> Keyword.get(:plans, %{})
    |> Enum.map(fn {key, plan} ->
      {key,
       %{
         key: plan[:key] || key,
         name: plan[:name],
         description: plan[:description],
         mode: plan[:mode],
         price_id: plan[:price_id]
       }}
    end)
    |> Map.new()
  end

  defp success_url do
    billing_config()
    |> Keyword.get(:success_url)
  end

  defp cancel_url do
    billing_config()
    |> Keyword.get(:cancel_url)
  end

  defp billing_config do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
  end
end
