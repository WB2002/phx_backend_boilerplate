defmodule PhxBackendBoilerplate.ReleaseTest do
  use PhxBackendBoilerplate.DataCase, async: false

  alias PhxBackendBoilerplate.Release

  test "migrate/0 is idempotent against an up-to-date database" do
    assert [{:ok, _, _}] = Release.migrate()
  end
end
