defmodule PhxBackendBoilerplate.JobsTest do
  use PhxBackendBoilerplate.DataCase, async: true
  use Oban.Testing, repo: PhxBackendBoilerplate.Repo

  alias PhxBackendBoilerplate.Jobs
  alias PhxBackendBoilerplate.RequestContext
  alias PhxBackendBoilerplate.Workers.DemoJob

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
end
