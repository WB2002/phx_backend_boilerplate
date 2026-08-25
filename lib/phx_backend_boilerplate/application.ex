defmodule PhxBackendBoilerplate.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhxBackendBoilerplateWeb.Telemetry,
      PhxBackendBoilerplate.Repo,
      {DNSCluster,
       query: Application.get_env(:phx_backend_boilerplate, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhxBackendBoilerplate.PubSub},
      {PhxBackendBoilerplate.RateLimit,
       Application.fetch_env!(:phx_backend_boilerplate, PhxBackendBoilerplate.RateLimit)},
      PhxBackendBoilerplate.LoadShed,
      {PhxBackendBoilerplate.Cache, []},
      PhxBackendBoilerplate.Cache.Coalescer,
      {Task.Supervisor, name: PhxBackendBoilerplate.Cache.TaskSupervisor},
      {Finch, name: PhxBackendBoilerplate.Finch},
      PhxBackendBoilerplate.Integrations.Example,
      # Start to serve requests, typically the last entry
      PhxBackendBoilerplateWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhxBackendBoilerplate.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxBackendBoilerplateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
