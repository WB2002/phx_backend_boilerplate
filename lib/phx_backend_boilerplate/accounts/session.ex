defmodule PhxBackendBoilerplate.Accounts.Session do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PhxBackendBoilerplate.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          user_id: Ecto.UUID.t() | nil,
          expires_at: DateTime.t() | nil,
          refresh_token_id: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "sessions" do
    belongs_to :user, User
    field :expires_at, :utc_datetime
    field :refresh_token_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:expires_at])
    |> validate_required([:expires_at])
  end
end
