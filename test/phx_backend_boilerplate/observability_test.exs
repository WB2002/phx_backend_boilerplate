defmodule PhxBackendBoilerplate.ObservabilityTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Observability
  alias PhxBackendBoilerplate.Observability.CloudWatchLogHandler
  alias PhxBackendBoilerplate.Observability.CloudWatchLogsClient.Fake

  setup do
    previous_client = Application.get_env(:phx_backend_boilerplate, :cloudwatch_logs_client)
    previous_obs = Application.get_env(:phx_backend_boilerplate, Observability)

    {:ok, _pid} = Fake.start_link()

    Application.put_env(
      :phx_backend_boilerplate,
      :cloudwatch_logs_client,
      Fake
    )

    on_exit(fn ->
      _ = :logger.remove_handler(:phx_backend_boilerplate_cloudwatch_logs)

      if GenServer.whereis(CloudWatchLogHandler) do
        GenServer.stop(CloudWatchLogHandler, :normal)
      end

      Fake.stop()

      if previous_client do
        Application.put_env(:phx_backend_boilerplate, :cloudwatch_logs_client, previous_client)
      else
        Application.delete_env(:phx_backend_boilerplate, :cloudwatch_logs_client)
      end

      if previous_obs do
        Application.put_env(:phx_backend_boilerplate, Observability, previous_obs)
      end
    end)

    :ok
  end

  test "feature flags default to false in test" do
    refute Observability.cloudwatch_logs_enabled?()
    refute Observability.cloudwatch_metrics_enabled?()
    refute Observability.otel_traces_enabled?()
  end

  test "cloudwatch log handler batches and flushes via client" do
    Application.put_env(:phx_backend_boilerplate, Observability,
      cloudwatch_logs_enabled: true,
      cloudwatch_metrics_enabled: false,
      otel_traces_enabled: false,
      cloudwatch_logs: [
        log_group: "/test/group",
        log_stream: "test-stream",
        flush_interval_ms: 50,
        max_batch: 10,
        level: :warning
      ],
      cloudwatch_metrics: []
    )

    assert :ok = Observability.attach_cloudwatch_logs!()

    # test.exs sets logger level to :warning, so info events are dropped.
    :logger.warning("observability unit test message", %{request_id: "req-1"})

    Process.sleep(150)
    _ = :sys.get_state(CloudWatchLogHandler)

    calls = Fake.calls()

    assert Enum.any?(calls, &match?({:create_log_group, "/test/group"}, &1))
    assert Enum.any?(calls, &match?({:create_log_stream, "/test/group", "test-stream"}, &1))

    assert Enum.any?(calls, fn
             {:put_log_events, "/test/group", "test-stream", events, nil} ->
               length(events) >= 1 and
                 Enum.all?(events, &match?(%{"timestamp" => _, "message" => _}, &1))

             _ ->
               false
           end)
  end
end
