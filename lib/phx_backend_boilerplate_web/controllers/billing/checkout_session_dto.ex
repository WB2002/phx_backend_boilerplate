defmodule PhxBackendBoilerplateWeb.Billing.CheckoutSessionDTO do
  @moduledoc """
  Request DTO for `POST /api/billing/checkout-sessions`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :plan, :string
  end

  @valid_plans ~w(lifetime pro)

  def changeset(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:plan])
    |> validate_required([:plan])
    |> validate_inclusion(:plan, @valid_plans)
  end
end
