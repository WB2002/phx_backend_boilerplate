defmodule PhxBackendBoilerplate.Seeds.Seeder do
  @moduledoc """
  Behaviour and `use` macro for versioned database seeders.

  ## Usage

      defmodule MyApp.Seeds.Widgets do
        use PhxBackendBoilerplate.Seeds.Seeder, version: 1

        @impl true
        def run do
          # insert / update seed data
          :ok
        end
      end

  Bump `version:` when the seeder's data or logic changes so the next
  `mix seed` re-runs it. Keep `run/0` safe to re-apply (idempotent).
  """

  @callback version() :: pos_integer()
  @callback run() :: :ok | {:error, term()}

  defmacro __using__(opts) do
    version = Keyword.fetch!(opts, :version)

    unless is_integer(version) and version > 0 do
      raise ArgumentError,
            "Seeds.Seeder expects version: to be a positive integer, got: #{inspect(version)}"
    end

    quote do
      @behaviour PhxBackendBoilerplate.Seeds.Seeder

      @impl true
      def version, do: unquote(version)
    end
  end
end
