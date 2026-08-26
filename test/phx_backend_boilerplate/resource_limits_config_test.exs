defmodule PhxBackendBoilerplate.ResourceLimitsConfigTest do
  use ExUnit.Case, async: true

  test "Repo config sets an explicit query timeout" do
    opts = Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Repo)
    assert Keyword.get(opts, :timeout) == 15_000
  end

  test "L1 cache config sets allocated_memory" do
    cache = Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Cache)
    [{PhxBackendBoilerplate.Cache.L1, l1} | _] = Keyword.fetch!(cache, :levels)
    assert Keyword.get(l1, :allocated_memory) > 0
  end
end
