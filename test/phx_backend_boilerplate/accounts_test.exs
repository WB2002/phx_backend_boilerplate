defmodule PhxBackendBoilerplate.AccountsTest do
  use PhxBackendBoilerplate.DataCase, async: true

  import Ecto.Query, only: []

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Accounts.ExpiredSessions
  alias PhxBackendBoilerplate.Accounts.Session
  alias PhxBackendBoilerplate.Repo

  @valid_attrs %{
    "email" => "user@example.com",
    "password" => "password123"
  }

  describe "register/1" do
    test "creates a user, session, and tokens" do
      assert {:ok, auth} = Accounts.register(@valid_attrs)
      assert auth.user.email == "user@example.com"
      assert is_binary(auth.session.id)
      assert is_binary(auth.access_token)
      assert is_binary(auth.refresh_token)
      assert auth.expires_in == Accounts.Tokens.access_ttl_seconds()
    end

    test "trims and downcases email on registration" do
      assert {:ok, auth} =
               Accounts.register(Map.put(@valid_attrs, "email", "  USER@Example.com  "))

      assert auth.user.email == "user@example.com"
    end

    test "rejects duplicate emails" do
      assert {:ok, _} = Accounts.register(@valid_attrs)

      assert {:error, changeset} = Accounts.register(@valid_attrs)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects short passwords" do
      assert {:error, changeset} =
               Accounts.register(Map.put(@valid_attrs, "password", "short"))

      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "rejects passwords longer than 72 bytes before hashing" do
      too_long = String.duplicate("a", 73)

      assert {:error, changeset} =
               Accounts.register(Map.put(@valid_attrs, "password", too_long))

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "accepts a 72-byte password" do
      password = String.duplicate("a", 72)

      assert {:ok, _auth} =
               Accounts.register(Map.put(@valid_attrs, "password", password))
    end
  end

  describe "login/2" do
    setup do
      {:ok, auth} = Accounts.register(@valid_attrs)
      %{auth: auth}
    end

    test "returns tokens for valid credentials", %{auth: auth} do
      assert {:ok, login_auth} = Accounts.login("user@example.com", "password123")
      assert login_auth.user.id == auth.user.id
      assert login_auth.session.id != auth.session.id
    end

    test "rejects invalid password" do
      assert {:error, :invalid_credentials} =
               Accounts.login("user@example.com", "wrong-password")
    end

    test "rejects oversized passwords without Argon2 verification" do
      too_long = String.duplicate("a", 73)

      assert {:error, :invalid_credentials} =
               Accounts.login("user@example.com", too_long)
    end

    test "rejects unknown email with same error" do
      assert {:error, :invalid_credentials} =
               Accounts.login("missing@example.com", "password123")
    end
  end

  describe "refresh/1" do
    setup do
      {:ok, auth} = Accounts.register(@valid_attrs)
      %{auth: auth}
    end

    test "rolls session expiry and re-issues tokens", %{auth: auth} do
      original_expires_at = auth.session.expires_at

      assert {:ok, refreshed} = Accounts.refresh(auth.refresh_token)
      assert DateTime.compare(refreshed.session.expires_at, original_expires_at) != :lt
      assert refreshed.session.updated_at >= auth.session.updated_at
      assert is_binary(refreshed.access_token)
      assert is_binary(refreshed.refresh_token)
    end

    test "rejects refresh when session was deleted", %{auth: auth} do
      :ok = Accounts.logout(auth.session.id)

      assert {:error, :session_not_found} = Accounts.refresh(auth.refresh_token)
    end

    test "allows only one concurrent refresh for the same token", %{auth: auth} do
      tasks =
        for _ <- 1..2 do
          Task.async(fn -> Accounts.refresh(auth.refresh_token) end)
        end

      results = Enum.map(tasks, &Task.await/1)
      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    end

    test "rotates refresh tokens and revokes session on reuse", %{auth: auth} do
      old_refresh = auth.refresh_token

      assert {:ok, refreshed} = Accounts.refresh(old_refresh)
      assert refreshed.refresh_token != old_refresh

      assert {:error, :session_not_found} = Accounts.refresh(old_refresh)
      refute Repo.get(Session, auth.session.id)
      assert ExpiredSessions.revoked?(auth.session.id)
    end
  end

  describe "logout/1" do
    test "broadcasts graphql socket disconnect" do
      {:ok, auth} = Accounts.register(@valid_attrs)
      user_id = auth.user.id
      session_id = auth.session.id
      topic = "graphql_socket:#{user_id}:#{session_id}"

      Phoenix.PubSub.subscribe(PhxBackendBoilerplate.PubSub, topic)

      :ok = Accounts.logout(session_id)

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^topic}
    end

    test "deletes the session and marks it expired in Redis" do
      {:ok, auth} = Accounts.register(@valid_attrs)

      :ok = Accounts.logout(auth.session.id)

      refute Repo.get(Session, auth.session.id)
      assert ExpiredSessions.revoked?(auth.session.id)
    end
  end
end
