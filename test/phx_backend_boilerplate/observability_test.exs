defmodule PhxBackendBoilerplate.ObservabilityTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Observability
  alias PhxBackendBoilerplate.Observability.CloudWatchLogHandler
  alias PhxBackendBoilerplate.Observability.CloudWatchLogsClient.Fake

  @logs_config %{
    log_group: "/test/group",
    log_stream: "test-stream",
    flush_interval_ms: 50,
    max_batch: 10
  }

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

      Fake.stop()

      if previous_client do
        Application.put_env(:phx_backend_boilerplate, :cloudwatch_logs_client, previous_client)
      else
        Application.delete_env(:phx_backend_boilerplate, :cloudwatch_logs_client)
      end

      if previous_obs do
        Application.put_env(:phx_backend_boilerplate, Observability, previous_obs)
      else
        Application.delete_env(:phx_backend_boilerplate, Observability)
      end
    end)

    :ok
  end

  test "feature flags default to false in test" do
    refute Observability.cloudwatch_logs_enabled?()
    refute Observability.cloudwatch_metrics_enabled?()
    refute Observability.otel_traces_enabled?()
  end

  test "attach fails when CloudWatch log handler is not supervised" do
    put_cloudwatch_logs_env()

    assert {:error, {:handler_not_added, :not_started}} =
             :logger.add_handler(
               :phx_backend_boilerplate_cloudwatch_logs,
               CloudWatchLogHandler,
               %{
                 level: :warning,
                 filter_default: :log,
                 filters: [],
                 config: @logs_config
               }
             )

    refute GenServer.whereis(CloudWatchLogHandler)
  end

  test "cloudwatch log handler batches and flushes via client" do
    put_cloudwatch_logs_env()
    start_supervised!({CloudWatchLogHandler, @logs_config})

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
               events != [] and
                 Enum.all?(events, &match?(%{"timestamp" => _, "message" => _}, &1))

             _ ->
               false
           end)
  end

  test "cloudwatch log handler redacts PII and secrets in reports" do
    put_cloudwatch_logs_env()
    start_supervised!({CloudWatchLogHandler, @logs_config})

    assert :ok = Observability.attach_cloudwatch_logs!()

    :logger.warning(%{
      password: "secret123",
      email: "user@example.com",
      user_id: "demo-user",
      request_id: "req-redact"
    })

    Process.sleep(150)
    _ = :sys.get_state(CloudWatchLogHandler)

    messages =
      Fake.calls()
      |> Enum.flat_map(fn
        {:put_log_events, "/test/group", "test-stream", events, _} ->
          Enum.map(events, & &1["message"])

        _ ->
          []
      end)

    assert messages != []

    Enum.each(messages, fn message ->
      refute message =~ "secret123"
      refute message =~ "user@example.com"
      assert message =~ "[REDACTED]"
      assert message =~ "demo-user"
    end)
  end

  test "cloudwatch log handler restarts and continues shipping" do
    put_cloudwatch_logs_env()
    start_supervised!({CloudWatchLogHandler, @logs_config})

    assert :ok = Observability.attach_cloudwatch_logs!()

    old_pid = GenServer.whereis(CloudWatchLogHandler)
    assert is_pid(old_pid)

    :logger.warning("before-restart-marker", %{request_id: "req-before"})
    Process.sleep(150)
    _ = :sys.get_state(CloudWatchLogHandler)

    Process.exit(old_pid, :kill)

    new_pid = wait_for_new_pid(old_pid)
    assert is_pid(new_pid)
    assert new_pid != old_pid

    :logger.warning("after-restart-marker", %{request_id: "req-after"})
    Process.sleep(150)
    _ = :sys.get_state(CloudWatchLogHandler)

    messages =
      Fake.calls()
      |> Enum.flat_map(fn
        {:put_log_events, "/test/group", "test-stream", events, _} ->
          Enum.map(events, & &1["message"])

        _ ->
          []
      end)

    assert Enum.any?(messages, &String.contains?(&1, "before-restart-marker"))
    assert Enum.any?(messages, &String.contains?(&1, "after-restart-marker"))
  end

  defp put_cloudwatch_logs_env do
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
  end

  defp wait_for_new_pid(old_pid, attempts \\ 50)

  defp wait_for_new_pid(_old_pid, 0) do
    flunk("CloudWatchLogHandler did not restart")
  end

  defp wait_for_new_pid(old_pid, attempts) do
    case GenServer.whereis(CloudWatchLogHandler) do
      ^old_pid ->
        Process.sleep(10)
        wait_for_new_pid(old_pid, attempts - 1)

      nil ->
        Process.sleep(10)
        wait_for_new_pid(old_pid, attempts - 1)

      new_pid ->
        new_pid
    end
  end
end
