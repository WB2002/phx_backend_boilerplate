defmodule PhxBackendBoilerplate.Lint.BannedIdentifiersTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Lint.BannedIdentifiers

  describe "banned?/1" do
    test "rejects NestJS placeholder names" do
      for name <- ~w(data result item temp obj val)a do
        assert BannedIdentifiers.banned?(name)
      end
    end

    test "rejects Go/FastAPI placeholder names" do
      for name <- ~w(tmp foo bar baz qux thing stuff dummy test_var my_var)a do
        assert BannedIdentifiers.banned?(name)
      end
    end

    test "rejects numbered varN pattern" do
      assert BannedIdentifiers.banned?(:var1)
      assert BannedIdentifiers.banned?("var99")
    end

    test "allows descriptive domain names" do
      refute BannedIdentifiers.banned?(:user_id)
      refute BannedIdentifiers.banned?(:checkout_session)
      refute BannedIdentifiers.banned?(:stripe_event)
    end

    test "message/1 includes the rejected name" do
      assert BannedIdentifiers.message(:foo) =~ "foo"
      assert BannedIdentifiers.message(:foo) =~ "domain"
    end
  end
end
