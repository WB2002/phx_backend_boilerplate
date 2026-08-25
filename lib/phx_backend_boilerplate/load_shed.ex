defmodule PhxBackendBoilerplate.LoadShed do
  @moduledoc """
  Installs named [Regulator](https://hexdocs.pm/regulator) concurrency limiters
  from application config at boot.

  Configure under `PhxBackendBoilerplate.LoadShed`:

      config :phx_backend_boilerplate, PhxBackendBoilerplate.LoadShed,
        regulators: [
          demo_expensive: {Regulator.Limit.Static, [limit: 2]},
          reports: {Regulator.Limit.AIMD, [timeout: 200, min_limit: 5, max_limit: 100]}
        ]

  Each name is passed to `Regulator.install/2`. Use the same atom with
  `PhxBackendBoilerplateWeb.Plugs.LoadShed` or `Regulator.ask/1` / `ask/2`.
  """

  use GenServer

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    regulators =
      :phx_backend_boilerplate
      |> Application.fetch_env!(__MODULE__)
      |> Keyword.fetch!(:regulators)

    Enum.each(regulators, fn {name, {mod, opts}} ->
      case Regulator.install(name, {mod, opts}) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        other -> raise "failed to install regulator #{inspect(name)}: #{inspect(other)}"
      end
    end)

    {:ok, %{regulators: Keyword.keys(regulators)}}
  end
end
