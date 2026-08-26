defmodule PhxBackendBoilerplate.JobsTest do
  use PhxBackendBoilerplate.DataCase, async: false
  use Oban.Testing, repo: PhxBackendBoilerplate.Repo

  alias PhxBackendBoilerplate.Integrations.Slack.Fake
  alias PhxBackendBoilerplate.Jobs
  alias PhxBackendBoilerplate.RequestContext
  alias PhxBackendBoilerplate.Workers.DemoJob

  setup do
    Fake.reset()

    on_exit(fn -> Fake.reset() end)

    :ok
  end

  test "enqueue_demo inserts a DemoJob" do
    assert {:ok, %Oban.Job{}} = Jobs.enqueue_demo(%{"message" => "hello", "work_ms" => 0})

    assert_enqueued(worker: DemoJob, args: %{"message" => "hello", "work_ms" => 0})
  end

  test "enqueue_demo copies request context into args" do
    RequestContext.with(%{request_id: "req-1", correlation_id: "corr-1", user_id: nil}, fn ->
      assert {:ok, _} = Jobs.enqueue_demo(%{"message" => "traced"})
    end)

    assert_enqueued(
      worker: DemoJob,
      args: %{
        "message" => "traced",
        "request_id" => "req-1",
        "correlation_id" => "corr-1"
      }
    )
  end

  test "enqueue_demo rejects missing message" do
    assert {:error, changeset} = Jobs.enqueue_demo(%{})
    assert %{message: ["can't be blank"]} = errors_on(changeset)
  end

  test "perform_job succeeds with message" do
    assert :ok = perform_job(DemoJob, %{"message" => "hello"})
  end

  test "perform_job errors without message" do
    assert {:error, :missing_message} = perform_job(DemoJob, %{})
  end

  test "enqueue_demo accepts notify_slack with channel" do
    assert {:ok, %Oban.Job{}} =
             Jobs.enqueue_demo(%{
               "message" => "hello",
               "notify_slack" => true,
               "slack_channel" => "C0123456789"
             })

    assert_enqueued(
      worker: DemoJob,
      args: %{
        "message" => "hello",
        "notify_slack" => true,
        "slack_channel" => "C0123456789"
      }
    )
  end

  test "enqueue_demo rejects notify_slack without channel when no default" do
    previous =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Slack, [])

    Application.put_env(
      :phx_backend_boilerplate,
      PhxBackendBoilerplate.Integrations.Slack,
      Keyword.put(previous, :default_channel, nil)
    )

    on_exit(fn ->
      Application.put_env(
        :phx_backend_boilerplate,
        PhxBackendBoilerplate.Integrations.Slack,
        previous
      )
    end)

    assert {:error, changeset} =
             Jobs.enqueue_demo(%{"message" => "hello", "notify_slack" => true})

    assert %{slack_channel: [_ | _]} = errors_on(changeset)
  end

  test "perform_job notifies Slack when notify_slack is true" do
    assert :ok =
             perform_job(DemoJob, %{
               "message" => "done",
               "notify_slack" => true,
               "slack_channel" => "C999"
             })

    assert [{"Demo job completed: done", "C999", _opts}] = Fake.calls()
  end

  test "perform_job does not notify Slack by default" do
    assert :ok = perform_job(DemoJob, %{"message" => "silent"})
    assert Fake.calls() == []
  end

  test "perform_job still succeeds when Slack notify fails" do
    Application.put_env(:phx_backend_boilerplate, Fake,
      result: {:error, {:slack, "channel_not_found"}}
    )

    assert :ok =
             perform_job(DemoJob, %{
               "message" => "done",
               "notify_slack" => true,
               "slack_channel" => "Cbad"
             })
  end
end
