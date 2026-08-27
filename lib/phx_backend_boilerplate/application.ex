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
        {Finch,
         name: PhxBackendBoilerplate.Finch,
         pools: %{
           "https://api.stripe.com" => [
             size: 5,
             count: 1,
             pool_max_idle_time: :timer.minutes(5)
           ],
           "https://slack.com" => [
             size: 5,
             count: 1,
             pool_max_idle_time: :timer.minutes(5)
           ],
           "https://www.google.com" => [
             size: 5,
             count: 1,
             pool_max_idle_time: :timer.minutes(5)
           ],
           default: [
             size: 10,
             count: 1,
             pool_max_idle_time: :timer.minutes(5)
           ]
         }}
      ] ++
        cloudwatch_log_handler_children() ++
        [
          PhxBackendBoilerplateWeb.Telemetry,
          PhxBackendBoilerplate.Repo,
          {Oban, Application.fetch_env!(:phx_backend_boilerplate, Oban)},
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
          PhxBackendBoilerplate.Integrations.Slack.WebAPI,
          PhxBackendBoilerplate.Integrations.Stripe.Api,
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

  defp cloudwatch_log_handler_children do
    if PhxBackendBoilerplate.Observability.cloudwatch_logs_enabled?() do
      config =
        PhxBackendBoilerplate.Observability.cloudwatch_logs_config()
        |> Map.new()

      [{PhxBackendBoilerplate.Observability.CloudWatchLogHandler, config}]
    else
      []
    end
  end
end
