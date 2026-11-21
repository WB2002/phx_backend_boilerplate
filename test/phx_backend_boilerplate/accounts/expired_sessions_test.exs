defmodule PhxBackendBoilerplate.Accounts.ExpiredSessionsTest do
  use PhxBackendBoilerplate.DataCase, async: false

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Accounts.ExpiredSessions
  alias PhxBackendBoilerplate.Accounts.ExpiredSessionsTest.CacheStub
  alias PhxBackendBoilerplate.Cache.L2

  @session_id Ecto.UUID.generate()
  @valid_attrs %{"email" => "expired@example.com", "password" => "password123"}

  setup do
    on_exit(fn -> L2.delete("expired_sessions:" <> @session_id) end)
    :ok
  end

  test "revoked? is false when no deny-list entry exists" do
    refute ExpiredSessions.revoked?(@session_id)
  end

  test "revoked? is false for an active session without a deny-list entry" do
    {:ok, auth} = Accounts.register(@valid_attrs)
    refute ExpiredSessions.revoked?(auth.session.id)
  end

  test "revoke/1 marks a session id as revoked" do
    :ok = ExpiredSessions.revoke(@session_id)
    assert ExpiredSessions.revoked?(@session_id)
  end

  describe "when Redis cache is unavailable" do
    setup do
      previous = Application.get_env(:phx_backend_boilerplate, ExpiredSessions, [])

      Application.put_env(
        :phx_backend_boilerplate,
        ExpiredSessions,
        Keyword.put(previous, :cache, CacheStub)
      )

      on_exit(fn ->
        Application.put_env(:phx_backend_boilerplate, ExpiredSessions, previous)
      end)

      :ok
    end

    test "revoke/1 returns :ok without raising when cache put fails" do
      assert :ok = ExpiredSessions.revoke(@session_id)
    end

    test "revoked?/1 is false when cache get fails and session row exists" do
      {:ok, auth} = Accounts.register(@valid_attrs)

      refute ExpiredSessions.revoked?(auth.session.id)
    end

    test "revoked?/1 is true when cache get fails and session row was deleted" do
      {:ok, auth} = Accounts.register(@valid_attrs)

      :ok = Accounts.logout(auth.session.id)

      assert ExpiredSessions.revoked?(auth.session.id)
    end
  end
end

defmodule PhxBackendBoilerplate.Accounts.ExpiredSessionsTest.CacheStub do
  @moduledoc false

  def put(_key, _value, _opts), do: {:error, :down}
  def get(_key), do: {:error, :down}
end
