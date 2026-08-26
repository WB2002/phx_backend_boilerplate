defmodule PhxBackendBoilerplateWeb.SocketAuthTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplateWeb.SocketAuth

  @claims %{"sub" => "demo-user", "email" => "demo@example.com"}

  test "sign/1 and verify/1 round-trip" do
    token = SocketAuth.sign(@claims)

    assert {:ok, @claims} = SocketAuth.verify(token)
  end

  test "verify/1 rejects garbage tokens" do
    assert {:error, :invalid} = SocketAuth.verify("not-a-real-token")
  end

  test "verify/1 rejects expired tokens when max_age is 0" do
    token = SocketAuth.sign(@claims)

    assert {:error, :expired} = SocketAuth.verify(token, max_age: 0)
  end
end
