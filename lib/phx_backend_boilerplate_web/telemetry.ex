defmodule PhxBackendBoilerplateWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://telemetry-metrics.hexdocs.pm
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
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

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {PhxBackendBoilerplateWeb, :count_users, []}
    ]
  end
end
