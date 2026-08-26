defmodule PhxBackendBoilerplate.Files.StoredFile do
  @moduledoc """
  Metadata for a validated, scanned, and stored upload.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stored_files" do
    field :filename, :string
    field :content_type, :string
    field :byte_size, :integer
    field :sha256, :string
    field :storage_backend, :string
    field :storage_key, :string

    timestamps(type: :utc_datetime)
  end

  @required ~w(filename content_type byte_size sha256 storage_backend storage_key)a

  @doc false
  def changeset(stored_file, attrs) do
    stored_file
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_length(:sha256, is: 64)
    |> validate_number(:byte_size, greater_than: 0)
    |> unique_constraint(:storage_key)
  end
end
