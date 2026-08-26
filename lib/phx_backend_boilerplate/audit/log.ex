defmodule PhxBackendBoilerplate.Audit.Log do
  @moduledoc """
  Append-only audit log row in the `audit` schema.

  Mutations are blocked at the database by triggers. Do not put secrets or
  credentials in `metadata`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "audit"
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :string
    field :actor_id, :string
    field :request_id, :string
    field :correlation_id, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required ~w(action)a
  @optional ~w(resource_type resource_id actor_id request_id correlation_id metadata)a

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> maybe_default_metadata()
  end

  defp maybe_default_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      _ -> changeset
    end
  end
end
