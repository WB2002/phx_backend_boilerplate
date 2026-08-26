defmodule PhxBackendBoilerplate.Observability do
  @moduledoc """
  Runtime helpers for CloudWatch logs/metrics and OpenTelemetry tracing.

  Feature flags (env, see `config/runtime.exs`):

  * `CLOUDWATCH_LOGS_ENABLED` — batched PutLogEvents Logger handler
  * `CLOUDWATCH_METRICS_ENABLED` — TelemetryMetricsCloudwatch reporter
  * `OTEL_TRACES_ENABLED` — Phoenix/Bandit/Ecto instrumentation + OTLP export
  """

  @doc "True when the CloudWatch Logs handler should attach."
  def cloudwatch_logs_enabled? do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:cloudwatch_logs_enabled, false)
  end

  @doc "True when TelemetryMetricsCloudwatch should start."
  def cloudwatch_metrics_enabled? do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:cloudwatch_metrics_enabled, false)
  end

  @doc "True when OpenTelemetry instrumentation should be installed."
  def otel_traces_enabled? do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:otel_traces_enabled, false)
  end

  @doc "CloudWatch Logs options (group, stream, flush settings)."
  def cloudwatch_logs_config do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:cloudwatch_logs, [])
  end

  @doc "CloudWatch Metrics reporter options (namespace, push_interval)."
  def cloudwatch_metrics_config do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:cloudwatch_metrics, [])
  end

  @doc """
  Installs OpenTelemetry instrumentation when enabled.

  Must run before the Endpoint starts accepting traffic.
  """
  def setup_tracing! do
    if otel_traces_enabled?() do
      OpentelemetryLoggerMetadata.setup()
      OpentelemetryBandit.setup()
      OpentelemetryPhoenix.setup(adapter: :bandit)
      OpentelemetryEcto.setup([:phx_backend_boilerplate, :repo])
    end

    :ok
  end

  @doc """
  Attaches the CloudWatch Logs Logger handler when enabled.

  Safe to call multiple times; re-attaching replaces the previous handler.
  """
  def attach_cloudwatch_logs! do
    if cloudwatch_logs_enabled?() do
      _ = :logger.remove_handler(:phx_backend_boilerplate_cloudwatch_logs)

      config = Map.new(cloudwatch_logs_config())
      level = Map.get(config, :level, :info)

      :ok =
        :logger.add_handler(
          :phx_backend_boilerplate_cloudwatch_logs,
          PhxBackendBoilerplate.Observability.CloudWatchLogHandler,
          %{
            level: level,
            filter_default: :log,
            filters: [],
            config: config
          }
        )
    end

    :ok
  end
end
