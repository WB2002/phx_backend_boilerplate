defmodule PhxBackendBoilerplate.AuditTest do
  use PhxBackendBoilerplate.DataCase, async: true

  alias PhxBackendBoilerplate.Audit
  alias PhxBackendBoilerplate.Audit.Log
  alias PhxBackendBoilerplate.Repo
  alias PhxBackendBoilerplate.RequestContext

  test "inserts a log with required action and default metadata" do
    assert {:ok, log} = Audit.log(%{action: "files.ingest"})
    assert log.action == "files.ingest"
    assert log.metadata == %{}
    assert %DateTime{} = log.inserted_at
    refute Map.has_key?(log, :updated_at)
  end

  test "requires action" do
    assert {:error, changeset} = Audit.log(%{})
    assert %{action: ["can't be blank"]} = errors_on(changeset)
  end

  test "fills actor_id, request_id, and correlation_id from request context" do
    RequestContext.with(
      %{request_id: "req-1", correlation_id: "corr-1", user_id: "user-1"},
      fn ->
        assert {:ok, log} = Audit.log(%{action: "demo.action"})
        assert log.actor_id == "user-1"
        assert log.request_id == "req-1"
        assert log.correlation_id == "corr-1"
      end
    )
  end

  test "explicit context fields are not overwritten by request context" do
    RequestContext.with(
      %{request_id: "req-ctx", correlation_id: "corr-ctx", user_id: "user-ctx"},
      fn ->
        assert {:ok, log} =
                 Audit.log(%{
                   action: "demo.action",
                   actor_id: "explicit-actor",
                   request_id: "explicit-req",
                   correlation_id: "explicit-corr"
                 })

        assert log.actor_id == "explicit-actor"
        assert log.request_id == "explicit-req"
        assert log.correlation_id == "explicit-corr"
      end
    )
  end

  test "database rejects UPDATE" do
    {:ok, log} = Audit.log(%{action: "demo.action"})

    assert_raise Postgrex.Error, ~r/audit\.audit_logs is append-only/, fn ->
      Repo.query!("UPDATE audit.audit_logs SET action = $1 WHERE id = $2", [
        "tampered",
        Ecto.UUID.dump!(log.id)
      ])
    end
  end

  test "database rejects DELETE" do
    {:ok, log} = Audit.log(%{action: "demo.action"})

    assert_raise Postgrex.Error, ~r/audit\.audit_logs is append-only/, fn ->
      Repo.query!("DELETE FROM audit.audit_logs WHERE id = $1", [Ecto.UUID.dump!(log.id)])
    end
  end

  test "database rejects TRUNCATE" do
    {:ok, _log} = Audit.log(%{action: "demo.action"})

    assert_raise Postgrex.Error, ~r/audit\.audit_logs is append-only/, fn ->
      Repo.query!("TRUNCATE audit.audit_logs")
    end
  end

  test "persists optional resource and metadata fields" do
    assert {:ok, log} =
             Audit.log(%{
               action: "files.delete",
               resource_type: "stored_file",
               resource_id: Ecto.UUID.generate(),
               metadata: %{"reason" => "user_request"}
             })

    reloaded = Repo.get!(Log, log.id)
    assert reloaded.resource_type == "stored_file"
    assert reloaded.metadata == %{"reason" => "user_request"}
  end
end
