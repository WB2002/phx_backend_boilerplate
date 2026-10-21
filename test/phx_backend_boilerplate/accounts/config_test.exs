defmodule PhxBackendBoilerplate.Accounts.ConfigTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Accounts.Config

  test "validate!/0 passes with default test configuration" do
    assert :ok = Config.validate!()
  end

  test "validate!/0 raises when deny_list_ttl is shorter than access_ttl" do
    previous = Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Accounts, [])

    Application.put_env(
      :phx_backend_boilerplate,
      PhxBackendBoilerplate.Accounts,
      Keyword.merge(previous, deny_list_ttl: :timer.minutes(1))
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Accounts, previous)
    end)

    assert_raise ArgumentError, ~r/deny_list_ttl/, fn -> Config.validate!() end
  end
end
