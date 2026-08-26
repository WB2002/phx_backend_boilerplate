defmodule PhxBackendBoilerplate.Accounts.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias PhxBackendBoilerplate.Accounts.Session
  alias PhxBackendBoilerplate.Crypto.Digest

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_digest, :string, redact: true

    has_many :sessions, Session

    timestamps(type: :utc_datetime)
  end

  @doc false
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:password, min: 8)
    |> update_change(:email, &String.downcase/1)
    |> unique_constraint(:email)
    |> put_password_digest()
  end

  defp put_password_digest(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        put_change(changeset, :password_digest, Digest.digest(password))
    end
  end
end
