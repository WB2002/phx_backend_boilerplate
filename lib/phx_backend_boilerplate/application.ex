defmodule PhxBackendBoilerplate.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Finch must start before ExAws/CloudWatch exporters use it.
    children =
      [
        {Finch, name: PhxBackendBoilerplate.Finch},
        PhxBackendBoilerplateWeb.Telemetry,
        PhxBackendBoilerplate.Repo,
        {DNSCluster,
         query: Application.get_env(:phx_backend_boilerplate, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: PhxBackendBoilerplate.PubSub},
        FunWithFlags.Supervisor,
        {PhxBackendBoilerplate.RateLimit,
         Application.fetch_env!(:phx_backend_boilerplate, PhxBackendBoilerplate.RateLimit)},
        PhxBackendBoilerplate.LoadShed,
        {PhxBackendBoilerplate.Cache, []},
        PhxBackendBoilerplate.Cache.Coalescer,
        {Task.Supervisor, name: PhxBackendBoilerplate.Cache.TaskSupervisor},
        PhxBackendBoilerplate.Integrations.Example,
        # Start to serve requests, typically the last entry
        PhxBackendBoilerplateWeb.Endpoint,
        {Absinthe.Subscription, PhxBackendBoilerplateWeb.Endpoint}
      ]

    :ok = PhxBackendBoilerplate.Observability.setup_tracing!()

    opts = [strategy: :one_for_one, name: PhxBackendBoilerplate.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        :ok = PhxBackendBoilerplate.Observability.attach_cloudwatch_logs!()
        {:ok, pid}

      other ->
        other
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxBackendBoilerplateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
