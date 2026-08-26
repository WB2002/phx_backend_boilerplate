defmodule PhxBackendBoilerplate.Accounts.TokensTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Accounts.Session
  alias PhxBackendBoilerplate.Accounts.Tokens

  @user_id Ecto.UUID.generate()
  @session_id Ecto.UUID.generate()

  setup do
    expires_at = DateTime.utc_now(:second) |> DateTime.add(7 * 24 * 60 * 60, :second)

    session = %Session{
      id: @session_id,
      user_id: @user_id,
      expires_at: expires_at
    }

    %{session: session}
  end

  test "access and refresh tokens carry jti, sub, and typ", %{session: session} do
    access = Tokens.generate_access_token(@user_id, @session_id)
    refresh = Tokens.generate_refresh_token(@user_id, session)

    assert {:ok, access_claims} = Tokens.verify_access(access)
    assert {:ok, refresh_claims} = Tokens.verify_refresh(refresh)

    assert access_claims["jti"] == @session_id
    assert access_claims["sub"] == @user_id
    assert access_claims["typ"] == "access"

    assert refresh_claims["jti"] == @session_id
    assert refresh_claims["sub"] == @user_id
    assert refresh_claims["typ"] == "refresh"
  end

  test "access token cannot be verified as refresh" do
    access = Tokens.generate_access_token(@user_id, @session_id)
    assert {:error, _} = Tokens.verify_refresh(access)
  end

  test "refresh token cannot be verified as access", %{session: session} do
    refresh = Tokens.generate_refresh_token(@user_id, session)
    assert {:error, _} = Tokens.verify_access(refresh)
  end

  test "tokens signed with different secrets are not interchangeable", %{session: session} do
    access = Tokens.generate_access_token(@user_id, @session_id)
    refresh = Tokens.generate_refresh_token(@user_id, session)

    previous =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Accounts)

    Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Accounts,
      access_secret: "other-access",
      refresh_secret: "other-refresh"
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Accounts, previous)
    end)

    assert {:error, _} = Tokens.verify_access(access)
    assert {:error, _} = Tokens.verify_refresh(refresh)
  end
end
