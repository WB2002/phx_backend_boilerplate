defmodule PhxBackendBoilerplate.Observability.LocalstackTest do
  use PhxBackendBoilerplateWeb.ConnCase, async: false

  require Logger

  @moduletag :localstack

  @log_group "/phx-backend-boilerplate/test-localstack"
  @log_stream "exunit-stream"

  setup do
    unless System.get_env("AWS_ENDPOINT_URL") do
      flunk("AWS_ENDPOINT_URL must be set for :localstack tests (e.g. http://localhost:4566)")
    end

    previous = Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Observability)

    Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Observability,
      cloudwatch_logs_enabled: true,
      cloudwatch_metrics_enabled: false,
      otel_traces_enabled: false,
      cloudwatch_logs: [
        log_group: @log_group,
        log_stream: @log_stream,
        flush_interval_ms: 300,
        max_batch: 10,
        level: :warning
      ],
      cloudwatch_metrics: []
    )

    on_exit(fn ->
      _ = :logger.remove_handler(:phx_backend_boilerplate_cloudwatch_logs)

      if previous do
        Application.put_env(
          :phx_backend_boilerplate,
          PhxBackendBoilerplate.Observability,
          previous
        )
      end
    end)

    :ok = PhxBackendBoilerplate.Observability.CloudWatchLogsClient.create_log_group(@log_group)

    :ok =
      PhxBackendBoilerplate.Observability.CloudWatchLogsClient.create_log_stream(
        @log_group,
        @log_stream
      )

    logs_config = %{
      log_group: @log_group,
      log_stream: @log_stream,
      flush_interval_ms: 300,
      max_batch: 10
    }

    start_supervised!({PhxBackendBoilerplate.Observability.CloudWatchLogHandler, logs_config})

    :ok = PhxBackendBoilerplate.Observability.attach_cloudwatch_logs!()
    :ok
  end

  test "writes logs to LocalStack CloudWatch Logs", %{conn: conn} do
    marker = "localstack-log-#{System.unique_integer([:positive])}"
    # test.exs logger level is :warning
    Logger.warning(marker)

    Process.sleep(1_200)

    assert {:ok, %{"events" => events}} =
             ExAws.CloudWatchLogs.get_log_events(@log_group, @log_stream, limit: 50)
             |> ExAws.request()

    assert Enum.any?(events, fn %{"message" => message} -> String.contains?(message, marker) end)

    conn = get(conn, ~p"/api/demo/public")
    assert json_response(conn, 200)
  end
end
