defmodule PhxBackendBoilerplate.Billing.Subscription do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PhxBackendBoilerplate.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "billing_subscriptions" do
    field :plan, :string
    field :stripe_subscription_id, :string
    field :stripe_price_id, :string
    field :status, :string
    field :current_period_end, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :user_id,
      :plan,
      :stripe_subscription_id,
      :stripe_price_id,
      :status,
      :current_period_end
    ])
    |> validate_required([:user_id, :plan, :stripe_subscription_id, :stripe_price_id, :status])
    |> unique_constraint(:stripe_subscription_id)
    |> foreign_key_constraint(:user_id)
  end
end
