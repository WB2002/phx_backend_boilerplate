defmodule PhxBackendBoilerplate.Repo.Migrations.CreateStoredFiles do
  use Ecto.Migration

  def change do
    create table(:stored_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :bigint, null: false
      add :sha256, :string, null: false, size: 64
      add :storage_backend, :string, null: false
      add :storage_key, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:stored_files, [:storage_key])
    create index(:stored_files, [:sha256])
  end
end
