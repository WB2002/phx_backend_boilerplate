# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     PhxBackendBoilerplate.Repo.insert!(%PhxBackendBoilerplate.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Enable the global preview demo flag for local exploration.
# Toggle via IEx or http://localhost:4000/dev/feature-flags
{:ok, true} = FunWithFlags.enable(:demo_preview)
