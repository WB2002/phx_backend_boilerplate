defmodule PhxBackendBoilerplate.Billing.Purchase do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias PhxBackendBoilerplate.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "billing_purchases" do
    field :plan, :string
    field :stripe_checkout_session_id, :string
    field :stripe_payment_intent_id, :string
    field :status, :string, default: "completed"

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(purchase, attrs) do
    purchase
    |> cast(attrs, [
      :user_id,
      :plan,
      :stripe_checkout_session_id,
      :stripe_payment_intent_id,
      :status
    ])
    |> validate_required([:user_id, :plan, :stripe_checkout_session_id, :status])
    |> unique_constraint(:stripe_checkout_session_id)
    |> foreign_key_constraint(:user_id)
  end
end
