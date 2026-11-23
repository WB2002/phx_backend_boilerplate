defmodule PhxBackendBoilerplate.CI.SecurityWorkflowTest do
  use ExUnit.Case, async: true

  @security_workflow_path Path.expand("../../.github/workflows/security.yml", __DIR__)

  test "pins hadolint/hadolint-action to the valid v3.1.0 commit SHA" do
    content = File.read!(@security_workflow_path)

    assert content =~ "hadolint/hadolint-action@54c9adbab1582c2ef04b2016b760714a4bfde3cf # v3.1.0"
    refute content =~ "54c9adabb6471c259114f14166f43474f7246290"
  end
end
