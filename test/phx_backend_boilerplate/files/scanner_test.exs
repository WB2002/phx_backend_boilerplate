defmodule PhxBackendBoilerplate.Files.ScannerTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Files.Scanner
  alias PhxBackendBoilerplate.Files.Scanner.AlwaysClean

  describe "skip_allowed?/1" do
    test "allows skip only in :dev" do
      assert Scanner.skip_allowed?(:dev)
      refute Scanner.skip_allowed?(:test)
      refute Scanner.skip_allowed?(:prod)
      refute Scanner.skip_allowed?(:staging)
    end
  end

  describe "resolve_skip_scanner/2" do
    test ":dev with skip enabled selects AlwaysClean" do
      assert {:ok, AlwaysClean} = Scanner.resolve_skip_scanner(:dev, true)
    end

    test ":prod with skip enabled is rejected" do
      assert {:error, :skip_not_allowed} = Scanner.resolve_skip_scanner(:prod, true)
    end

    test "custom env with skip enabled is rejected" do
      assert {:error, :skip_not_allowed} = Scanner.resolve_skip_scanner(:staging, true)
    end

    test ":test with skip enabled leaves config unchanged" do
      assert {:ok, :unchanged} = Scanner.resolve_skip_scanner(:test, true)
    end

    test "skip disabled leaves config unchanged in any env" do
      for env <- [:dev, :test, :prod, :staging] do
        assert {:ok, :unchanged} = Scanner.resolve_skip_scanner(env, false)
      end
    end
  end
end
