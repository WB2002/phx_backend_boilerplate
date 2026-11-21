defmodule Mix.Tasks.Semgrep.Guardrails do
  @shortdoc "Run Semgrep guardrails (banned identifier names)"
  @moduledoc false
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    script = Path.expand("scripts/ci/run-semgrep-guardrails.sh")

    unless File.exists?(script) do
      Mix.raise("Missing #{script}")
    end

    Mix.shell().info("Running semgrep guardrails…")

    case System.cmd(script, [], into: IO.stream(:stdio, :line)) do
      {_, 0} -> :ok
      {_, code} -> Mix.raise("semgrep guardrails failed with exit code #{code}")
    end
  end
end
