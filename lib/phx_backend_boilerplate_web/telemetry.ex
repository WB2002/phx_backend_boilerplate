defmodule PhxBackendBoilerplateWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children =
      [
        # Telemetry poller will execute the given period measurements
        # every 10_000ms. Learn more here: https://telemetry-metrics.hexdocs.pm
        {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      ] ++ cloudwatch_reporter_children()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp cloudwatch_reporter_children do
    if PhxBackendBoilerplate.Observability.cloudwatch_metrics_enabled?() do
      opts = PhxBackendBoilerplate.Observability.cloudwatch_metrics_config()

      [
        {TelemetryMetricsCloudwatch,
         [
           metrics: metrics(),
           namespace: Keyword.get(opts, :namespace, "PhxBackendBoilerplate"),
           push_interval: Keyword.get(opts, :push_interval, 60_000)
         ]}
      ]
    else
      []
    end
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("phx_backend_boilerplate.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("phx_backend_boilerplate.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("phx_backend_boilerplate.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("phx_backend_boilerplate.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("phx_backend_boilerplate.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # Regulator (load shedding) metrics
      summary("regulator.ask.stop.duration",
        tags: [:regulator, :result],
        unit: {:native, :millisecond},
        description: "Time from ask until token check-in or drop"
      ),
      counter("regulator.ask.stop.result",
        event_name: [:regulator, :ask, :stop],
        tags: [:regulator, :result],
        description: "Regulator ask outcomes (ok, dropped, error, ignore)"
      ),
      last_value("regulator.limit.limit",
        event_name: [:regulator, :limit],
        tags: [:regulator],
        description: "Current adaptive concurrency limit"
      ),

      # ExternalService (outbound resilience) metrics
      summary("external_service.call.stop.duration",
        tags: [:service],
        unit: {:native, :millisecond},
        description: "Guarded outbound call duration"
      ),
      counter("external_service.call.retry.count",
        event_name: [:external_service, :call, :retry],
        measurement: :count,
        tags: [:service],
        description: "Outbound call retries (melts circuit breaker)"
      ),
      counter("external_service.circuit_breaker.blown.count",
        event_name: [:external_service, :circuit_breaker, :blown],
        measurement: :count,
        tags: [:service],
        description: "Calls rejected because circuit breaker is open"
      ),

      # SWR cache metrics
      summary("phx_backend_boilerplate.swr.fetch.stop.duration",
        tags: [:freshness],
        tag_values: &swr_fetch_tags/1,
        unit: {:native, :millisecond},
        description: "SWR fetch duration by freshness"
      ),
      counter("phx_backend_boilerplate.swr.fetch.stop.freshness",
        event_name: [:phx_backend_boilerplate, :swr, :fetch, :stop],
        tags: [:freshness],
        tag_values: &swr_fetch_tags/1,
        description: "SWR fetch outcomes by freshness"
      ),
      counter("phx_backend_boilerplate.swr.lock.stop.result",
        event_name: [:phx_backend_boilerplate, :swr, :lock, :stop],
        tags: [:result],
        description: "Stampede lock acquired vs contended"
      ),
      counter("phx_backend_boilerplate.swr.refresh.stop.result",
        event_name: [:phx_backend_boilerplate, :swr, :refresh, :stop],
        tags: [:result],
        tag_values: &swr_refresh_tags/1,
        description: "Background SWR refresh outcomes"
      ),
      counter("phx_backend_boilerplate.swr.refresh.exception.count",
        event_name: [:phx_backend_boilerplate, :swr, :refresh, :exception],
        description: "Background SWR refresh exceptions"
      ),
      summary("phx_backend_boilerplate.cache.command.stop.duration",
        tags: [:command],
        unit: {:native, :millisecond},
        description: "Nebulex multilevel cache command duration"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp swr_fetch_tags(metadata) do
    %{freshness: Map.get(metadata, :freshness, :unknown)}
  end

  defp swr_refresh_tags(metadata) do
    %{result: Map.get(metadata, :result, :unknown)}
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {PhxBackendBoilerplateWeb, :count_users, []}
    ]
  end
end
