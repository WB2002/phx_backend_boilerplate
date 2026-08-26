defmodule Mix.Tasks.Seed do
  @shortdoc "Run pending / outdated versioned seeders"
  @moduledoc """
  Runs registered seeders from `PhxBackendBoilerplate.Seeds`.

  A seeder runs when it has never been recorded, or when its `version/0`
  differs from the version stored in the `seeders` table. Same version is
  skipped. Bump `version:` on a seeder module to re-apply it.

      mix seed

  Also invoked via `priv/repo/seeds.exs` (`mix ecto.setup`).
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Running seeders…")

    case PhxBackendBoilerplate.Seeds.run() do
      {:ok, %{ran: ran, skipped: skipped}} ->
        Enum.each(ran, fn module ->
          Mix.shell().info("  ran     #{inspect(module)} v#{module.version()}")
        end)

        Enum.each(skipped, fn module ->
          Mix.shell().info("  skipped #{inspect(module)} v#{module.version()}")
        end)

        Mix.shell().info("Done (#{length(ran)} ran, #{length(skipped)} skipped)")

      {:error, {module, reason}} ->
        Mix.raise("Seeder #{inspect(module)} failed: #{inspect(reason)}")
    end
  end
end
