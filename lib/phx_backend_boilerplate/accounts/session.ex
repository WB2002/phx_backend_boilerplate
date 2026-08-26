defmodule PhxBackendBoilerplate.Accounts.Session do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PhxBackendBoilerplate.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    belongs_to :user, User
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:expires_at])
    |> validate_required([:expires_at])
  end
end
