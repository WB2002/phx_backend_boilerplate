defmodule PhxBackendBoilerplate.Repo.Migrations.AddBillingTables do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :stripe_customer_id, :string
    end

    create unique_index(:users, [:stripe_customer_id], where: "stripe_customer_id IS NOT NULL")

    create table(:billing_purchases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :plan, :string, null: false
      add :stripe_checkout_session_id, :string, null: false
      add :stripe_payment_intent_id, :string
      add :status, :string, null: false, default: "completed"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:billing_purchases, [:stripe_checkout_session_id])
    create index(:billing_purchases, [:user_id])

    create table(:billing_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :plan, :string, null: false
      add :stripe_subscription_id, :string, null: false
      add :stripe_price_id, :string, null: false
      add :status, :string, null: false
      add :current_period_end, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:billing_subscriptions, [:stripe_subscription_id])
    create index(:billing_subscriptions, [:user_id])

    create table(:stripe_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_event_id, :string, null: false
      add :event_type, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:stripe_events, [:stripe_event_id])
  end
end
