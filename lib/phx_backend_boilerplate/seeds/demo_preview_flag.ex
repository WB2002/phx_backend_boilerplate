defmodule PhxBackendBoilerplate.Seeds.DemoPreviewFlag do
  @moduledoc """
  Enables the global `:demo_preview` feature flag for local exploration.

  Bump `version:` if this seeder's behaviour changes and needs re-application.
  """

  use PhxBackendBoilerplate.Seeds.Seeder, version: 1

  @impl true
  def run do
    case FunWithFlags.enable(:demo_preview) do
      {:ok, true} -> :ok
      other -> {:error, other}
    end
  end
end
