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

  @max_status_purchases 50

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
      |> limit(^max_status_purchases())
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
  Maximum purchase rows returned by `get_status/1`.
  """
  @spec max_status_purchases() :: pos_integer()
  def max_status_purchases, do: @max_status_purchases

  @subscription_replace_fields [
    :plan,
    :stripe_price_id,
    :status,
    :current_period_end,
    :updated_at
  ]

  @doc """
  Records a Stripe webhook event idempotently and applies side effects.

  Stripe HTTP calls happen before the database transaction. Entitlement writes
  and the event row commit atomically via `Ecto.Multi`. Recoverable failures
  return `{:error, reason}` so Oban can retry without leaving a processed event
  without entitlements.

  Returns `:ok`, `{:ok, :duplicate}`, or `{:error, reason}`.
  """
  @spec handle_event(map()) :: :ok | {:ok, :duplicate} | {:error, term()}
  def handle_event(%{"id" => event_id, "type" => type} = event)
      when is_binary(event_id) and is_binary(type) do
    case prepare_event(event) do
      {:ok, multi} -> persist_event(multi)
      {:skip, ^event_id, ^type} -> persist_event_only(event_id, type)
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_event(_), do: {:error, :invalid_event}

  defp prepare_event(%{
         "id" => event_id,
         "type" => "checkout.session.completed",
         "data" => %{"object" => session}
       }) do
    case session["mode"] do
      "payment" ->
        case purchase_attrs_from_session(session) do
          {:ok, attrs} ->
            {:ok, event_multi(event_id, "checkout.session.completed") |> purchase_multi(attrs)}

          :skip ->
            {:skip, event_id, "checkout.session.completed"}
        end

      "subscription" ->
        case session["subscription"] do
          subscription_id when is_binary(subscription_id) ->
            with {:ok, subscription} <- Stripe.retrieve_subscription(subscription_id),
                 {:ok, attrs} <- subscription_attrs_from_stripe(subscription, session) do
              {:ok,
               event_multi(event_id, "checkout.session.completed") |> subscription_multi(attrs)}
            else
              {:error, reason} -> {:error, reason}
              :skip -> {:skip, event_id, "checkout.session.completed"}
            end

          _ ->
            {:skip, event_id, "checkout.session.completed"}
        end

      _ ->
        {:skip, event_id, "checkout.session.completed"}
    end
  end

  defp prepare_event(%{"id" => event_id, "type" => type, "data" => %{"object" => subscription}})
       when type in ["customer.subscription.updated", "customer.subscription.deleted"] do
    case subscription_attrs_from_stripe(subscription, nil) do
      {:ok, attrs} ->
        {:ok, event_multi(event_id, type) |> subscription_multi(attrs)}

      :skip ->
        {:skip, event_id, type}
    end
  end

  defp prepare_event(%{"id" => event_id, "type" => type}), do: {:skip, event_id, type}

  defp persist_event(multi) do
    case Repo.transaction(multi) do
      {:ok, _results} ->
        :ok

      {:error, :stripe_event, %Ecto.Changeset{errors: errors}, _changes} ->
        if duplicate_event?(errors) do
          {:ok, :duplicate}
        else
          {:error, :invalid_event}
        end

      {:error, _failed_op, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}

      {:error, _failed_op, reason, _changes} ->
        {:error, reason}
    end
  end

  defp persist_event_only(event_id, type) do
    case insert_stripe_event(event_id, type) do
      {:ok, _} ->
        :ok

      {:error, %Ecto.Changeset{errors: errors}} ->
        if duplicate_event?(errors) do
          {:ok, :duplicate}
        else
          {:error, :invalid_event}
        end
    end
  end

  defp event_multi(event_id, type) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :stripe_event,
      StripeEvent.changeset(%StripeEvent{}, %{
        stripe_event_id: event_id,
        event_type: type
      })
    )
  end

  defp purchase_multi(multi, attrs) do
    Ecto.Multi.insert(
      multi,
      :purchase,
      Purchase.changeset(%Purchase{}, attrs),
      on_conflict: :nothing,
      conflict_target: :stripe_checkout_session_id
    )
  end

  defp subscription_multi(multi, attrs) do
    Ecto.Multi.insert(
      multi,
      :subscription,
      Subscription.changeset(%Subscription{}, attrs),
      on_conflict: {:replace, @subscription_replace_fields},
      conflict_target: :stripe_subscription_id
    )
  end

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

  defp purchase_attrs_from_session(session) do
    user_id = session_user_id(session)
    session_id = session["id"]

    if user_id && session_id do
      {:ok,
       %{
         user_id: user_id,
         plan: get_in(session, ["metadata", "plan"]) || "lifetime",
         stripe_checkout_session_id: session_id,
         stripe_payment_intent_id: session["payment_intent"],
         status: "completed"
       }}
    else
      :skip
    end
  end

  defp subscription_attrs_from_stripe(subscription, checkout_session) do
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

      {:ok,
       %{
         user_id: user_id,
         plan: plan,
         stripe_subscription_id: subscription_id,
         stripe_price_id: subscription_price_id(subscription),
         status: subscription["status"],
         current_period_end: unix_to_datetime(subscription["current_period_end"])
       }}
    else
      :skip
    end
  end

  defp ensure_stripe_customer(%User{stripe_customer_id: id}) when is_binary(id) and id != "" do
    {:ok, id}
  end

  defp ensure_stripe_customer(%User{id: user_id} = user) do
    with nil <- reload_stripe_customer_id(user_id),
         {:ok, customer} <-
           Stripe.create_customer(user.email, idempotency_key: customer_idempotency_key(user_id)),
         {:ok, customer_id} <- persist_stripe_customer_id(user_id, customer["id"]) do
      {:ok, customer_id}
    else
      customer_id when is_binary(customer_id) -> {:ok, customer_id}
      other -> other
    end
  end

  defp reload_stripe_customer_id(user_id) do
    User
    |> where([u], u.id == ^user_id)
    |> select([u], u.stripe_customer_id)
    |> Repo.one()
    |> case do
      id when is_binary(id) and id != "" -> id
      _ -> nil
    end
  end

  defp persist_stripe_customer_id(user_id, customer_id) do
    Repo.transaction(fn ->
      user =
        User
        |> where([u], u.id == ^user_id)
        |> lock("FOR UPDATE")
        |> Repo.one!()

      case user.stripe_customer_id do
        existing when is_binary(existing) and existing != "" ->
          existing

        _ ->
          user
          |> Ecto.Changeset.change(stripe_customer_id: customer_id)
          |> Repo.update!()
          |> Map.fetch!(:stripe_customer_id)
      end
    end)
  end

  defp customer_idempotency_key(user_id), do: "customer-#{user_id}"

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
