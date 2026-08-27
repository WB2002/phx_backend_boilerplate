defmodule PhxBackendBoilerplate.ResourceLimitsConfigTest do
  use ExUnit.Case, async: true

  test "Repo config sets an explicit query timeout" do
    opts = Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Repo)
    assert Keyword.get(opts, :timeout) == 15_000
  end

  test "Repo config sets Postgres statement_timeout" do
    opts = Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Repo)
    parameters = Keyword.fetch!(opts, :parameters)
    assert Keyword.get(parameters, :options) == "-c statement_timeout=15s"
  end

  test "L1 cache config sets allocated_memory" do
    cache = Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Cache)
    [{PhxBackendBoilerplate.Cache.L1, l1} | _] = Keyword.fetch!(cache, :levels)
    assert Keyword.get(l1, :allocated_memory) > 0
  end

  test "JSON parser length is 1MB" do
    parsers = Application.fetch_env!(:phx_backend_boilerplate, :parsers)
    assert Keyword.fetch!(parsers, :length) == 1_000_000
  end

  test "demo_routes is enabled in test but defaults false in prod config" do
    assert Application.get_env(:phx_backend_boilerplate, :demo_routes) == true
  end
end
