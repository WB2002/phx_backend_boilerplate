defmodule PhxBackendBoilerplate.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def up do
    execute("CREATE SCHEMA IF NOT EXISTS audit")

    create table(:audit_logs, primary_key: false, prefix: "audit") do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :resource_type, :string
      add :resource_id, :string
      add :actor_id, :string
      add :request_id, :string
      add :correlation_id, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_logs, [:inserted_at], prefix: "audit")
    create index(:audit_logs, [:actor_id], prefix: "audit")
    create index(:audit_logs, [:request_id], prefix: "audit")
    create index(:audit_logs, [:resource_type, :resource_id], prefix: "audit")

    execute("""
    CREATE OR REPLACE FUNCTION audit.reject_mutation()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'audit.audit_logs is append-only'
        USING ERRCODE = 'restrict_violation';
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER audit_logs_reject_row_mutation
    BEFORE UPDATE OR DELETE ON audit.audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION audit.reject_mutation();
    """)

    execute("""
    CREATE TRIGGER audit_logs_reject_truncate
    BEFORE TRUNCATE ON audit.audit_logs
    FOR EACH STATEMENT
    EXECUTE FUNCTION audit.reject_mutation();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS audit_logs_reject_truncate ON audit.audit_logs")
    execute("DROP TRIGGER IF EXISTS audit_logs_reject_row_mutation ON audit.audit_logs")
    execute("DROP FUNCTION IF EXISTS audit.reject_mutation()")
    drop table(:audit_logs, prefix: "audit")
    execute("DROP SCHEMA IF EXISTS audit")
  end
end
