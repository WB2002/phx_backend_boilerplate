defmodule PhxBackendBoilerplate.Workers.PurgeExpiredSessionsJobTest do
  use PhxBackendBoilerplate.DataCase, async: false

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Accounts.Session
  alias PhxBackendBoilerplate.Repo
  alias PhxBackendBoilerplate.Workers.PurgeExpiredSessionsJob

  test "perform/1 deletes expired session rows" do
    {:ok, auth} =
      Accounts.register(%{"email" => "purge@example.com", "password" => "password123"})

    past = DateTime.utc_now(:second) |> DateTime.add(-3600, :second)
    future = DateTime.utc_now(:second) |> DateTime.add(3600, :second)

    expired =
      auth.session
      |> Session.changeset(%{expires_at: past})
      |> Repo.update!()

    {:ok, active} =
      %Session{user_id: auth.user.id}
      |> Session.changeset(%{expires_at: future})
      |> Repo.insert()

    assert :ok = PurgeExpiredSessionsJob.perform(%Oban.Job{})

    refute Repo.get(Session, expired.id)
    assert Repo.get(Session, active.id)
  end
end
