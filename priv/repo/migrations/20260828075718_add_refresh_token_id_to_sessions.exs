defmodule PhxBackendBoilerplate.Repo.Migrations.AddRefreshTokenIdToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :refresh_token_id, :binary_id, null: false, default: fragment("gen_random_uuid()")
    end
  end
end
