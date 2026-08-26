defmodule Mix.Tasks.Gitleaks do
  @shortdoc "Scan for secrets with gitleaks"
  @moduledoc """
  Runs [gitleaks](https://github.com/gitleaks/gitleaks) against the repo.

  Requires the `gitleaks` binary on PATH (`brew install gitleaks`).

      mix gitleaks           # detect secrets in the working tree
      mix gitleaks --staged  # protect staged files (same as the git hook)

  Used by `mix precommit` and the `.githooks/pre-commit` hook.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    unless System.find_executable("gitleaks") do
      Mix.raise("""
      gitleaks is not installed or not on PATH.
      Install with: brew install gitleaks
      """)
    end

    config = Path.expand(".gitleaks.toml")

    cmd_args =
      if "--staged" in args do
        ["protect", "--staged", "--redact", "--no-banner", "--config", config]
      else
        ["detect", "--source", ".", "--redact", "--no-banner", "--config", config]
      end

    Mix.shell().info("Running gitleaks…")

    case System.cmd("gitleaks", cmd_args, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info("gitleaks: no leaks detected")

      {_, exit_code} ->
        Mix.raise("gitleaks failed with exit code #{exit_code}")
    end
  end
end
