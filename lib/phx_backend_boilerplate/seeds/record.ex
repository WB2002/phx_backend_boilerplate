defmodule PhxBackendBoilerplate.Seeds.Record do
  @moduledoc """
  Tracks which seeders have been applied and at which version.

  Rows are written only by `PhxBackendBoilerplate.Seeds` after a successful
  `run/0`. Bumping a seeder's `version:` causes a re-run on the next
  `mix seed`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "seeders" do
    field :name, :string
    field :version, :integer

    timestamps(type: :utc_datetime)
  end

  @required ~w(name version)a

  @doc false
  def changeset(record, attrs) do
    record
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_number(:version, greater_than: 0)
    |> unique_constraint(:name)
  end
end
