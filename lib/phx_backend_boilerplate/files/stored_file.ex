defmodule PhxBackendBoilerplate.Files.StoredFile do
  @moduledoc """
  Metadata for a validated, scanned, and stored upload.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          filename: String.t() | nil,
          content_type: String.t() | nil,
          byte_size: non_neg_integer() | nil,
          sha256: String.t() | nil,
          storage_backend: String.t() | nil,
          storage_key: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

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
