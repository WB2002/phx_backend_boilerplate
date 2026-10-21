defmodule PhxBackendBoilerplate.Workers.PurgeExpiredSessionsJob do
  @moduledoc """
  Deletes session rows whose inactivity deadline has passed.

  Scheduled via Oban cron so the `sessions` table does not grow without bound.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query

  alias PhxBackendBoilerplate.Accounts.Session
  alias PhxBackendBoilerplate.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now(:second)

    _ = Repo.delete_all(from(s in Session, where: s.expires_at <= ^now))

    :ok
  end
end
