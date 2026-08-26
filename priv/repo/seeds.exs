# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#     mix seed
#
# Seeders are versioned modules under PhxBackendBoilerplate.Seeds.
# Already-applied versions are skipped; bump a seeder's `version:` to re-run it.

PhxBackendBoilerplate.Seeds.run()
|> case do
  {:ok, %{ran: ran, skipped: skipped}} ->
    IO.puts("Seeds ran: #{inspect(ran)}")
    IO.puts("Seeds skipped: #{inspect(skipped)}")

  {:error, {module, reason}} ->
    raise "Seeder #{inspect(module)} failed: #{inspect(reason)}"
end
