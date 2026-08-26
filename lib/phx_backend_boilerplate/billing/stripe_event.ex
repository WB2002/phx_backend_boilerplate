defmodule PhxBackendBoilerplate.Billing.StripeEvent do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stripe_events" do
    field :stripe_event_id, :string
    field :event_type, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:stripe_event_id, :event_type])
    |> validate_required([:stripe_event_id, :event_type])
    |> unique_constraint(:stripe_event_id)
  end
end
