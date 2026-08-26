defmodule PhxBackendBoilerplate.Accounts.ExpiredSessionsTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Accounts.ExpiredSessions
  alias PhxBackendBoilerplate.Cache.L2

  @session_id Ecto.UUID.generate()

  setup do
    on_exit(fn -> L2.delete("expired_sessions:" <> @session_id) end)
    :ok
  end

  test "revoked? is false until revoke/1 is called" do
    refute ExpiredSessions.revoked?(@session_id)
  end

  test "revoke/1 marks a session id as revoked" do
    :ok = ExpiredSessions.revoke(@session_id)
    assert ExpiredSessions.revoked?(@session_id)
  end
end
