defmodule PhxBackendBoilerplateWeb.Demo.JobsController do
  @moduledoc """
  Demo endpoint for enqueueing Oban jobs.

  `POST /api/demo/jobs` with `{"message":"hello","work_ms":0}` returns **202**
  and the inserted job metadata without waiting for `perform/1`.

  Optional Slack notify after completion:

      {"message":"hello","notify_slack":true,"slack_channel":"C0123456789"}
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.Jobs

  action_fallback PhxBackendBoilerplateWeb.FallbackController

  def create(conn, params) do
    with {:ok, job} <- Jobs.enqueue_demo(params) do
      conn
      |> put_status(:accepted)
      |> json(%{
        data: %{
          id: job.id,
          state: job.state,
          queue: job.queue,
          worker: job.worker,
          args: job.args
        }
      })
    end
  end
end
