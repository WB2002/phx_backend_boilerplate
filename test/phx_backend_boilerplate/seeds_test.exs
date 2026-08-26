defmodule PhxBackendBoilerplate.SeedsTest do
  use PhxBackendBoilerplate.DataCase, async: false

  alias PhxBackendBoilerplate.Seeds
  alias PhxBackendBoilerplate.Seeds.Record

  defmodule OkV1 do
    use PhxBackendBoilerplate.Seeds.Seeder, version: 1

    @impl true
    def run do
      Agent.update(PhxBackendBoilerplate.SeedsTest.Runs, &(&1 + 1))
      :ok
    end
  end

  defmodule BumpV2 do
    use PhxBackendBoilerplate.Seeds.Seeder, version: 2

    @impl true
    def run do
      Agent.update(PhxBackendBoilerplate.SeedsTest.Runs, &(&1 + 1))
      :ok
    end
  end

  defmodule Failing do
    use PhxBackendBoilerplate.Seeds.Seeder, version: 1

    @impl true
    def run, do: {:error, :boom}
  end

  defmodule FailingV2 do
    use PhxBackendBoilerplate.Seeds.Seeder, version: 2

    @impl true
    def run, do: {:error, :boom}
  end

  defmodule Raising do
    use PhxBackendBoilerplate.Seeds.Seeder, version: 1

    @impl true
    def run, do: raise("explode")
  end

  defmodule AfterFail do
    use PhxBackendBoilerplate.Seeds.Seeder, version: 1

    @impl true
    def run do
      Agent.update(PhxBackendBoilerplate.SeedsTest.Runs, &(&1 + 1))
      :ok
    end
  end

  setup do
    start_supervised!(%{
      id: __MODULE__.Runs,
      start: {Agent, :start_link, [fn -> 0 end, [name: __MODULE__.Runs]]}
    })

    :ok
  end

  test "pending seeder runs and stores name + version" do
    assert {:ok, %{ran: [OkV1], skipped: []}} = Seeds.run([OkV1])
    assert Agent.get(__MODULE__.Runs, & &1) == 1

    name = Atom.to_string(OkV1)
    assert %Record{name: ^name, version: 1} = Repo.get_by(Record, name: name)
  end

  test "same version is skipped on second run" do
    assert {:ok, %{ran: [OkV1], skipped: []}} = Seeds.run([OkV1])
    assert {:ok, %{ran: [], skipped: [OkV1]}} = Seeds.run([OkV1])
    assert Agent.get(__MODULE__.Runs, & &1) == 1
  end

  test "version mismatch re-runs and updates the stored version" do
    name = Atom.to_string(BumpV2)

    %Record{}
    |> Record.changeset(%{name: name, version: 1})
    |> Repo.insert!()

    assert {:ok, %{ran: [BumpV2], skipped: []}} = Seeds.run([BumpV2])
    assert Agent.get(__MODULE__.Runs, & &1) == 1
    assert %Record{version: 2} = Repo.get_by(Record, name: name)
  end

  test "error on first run leaves no row and stops later seeders" do
    assert {:error, {Failing, :boom}} = Seeds.run([Failing, AfterFail])
    assert is_nil(Repo.get_by(Record, name: Atom.to_string(Failing)))
    assert Agent.get(__MODULE__.Runs, & &1) == 0
  end

  test "raise on first run leaves no row" do
    assert {:error, {Raising, %RuntimeError{}}} = Seeds.run([Raising])
    assert is_nil(Repo.get_by(Record, name: Atom.to_string(Raising)))
  end

  test "failed version bump leaves prior version unchanged and stops later seeders" do
    name = Atom.to_string(FailingV2)

    %Record{}
    |> Record.changeset(%{name: name, version: 1})
    |> Repo.insert!()

    assert {:error, {FailingV2, :boom}} = Seeds.run([FailingV2, AfterFail])
    assert %Record{version: 1} = Repo.get_by(Record, name: name)
    assert Agent.get(__MODULE__.Runs, & &1) == 0
  end

  test "default registry lists both real seeders" do
    seeders = Seeds.seeders()

    assert PhxBackendBoilerplate.Seeds.DemoPreviewFlag in seeders
    assert PhxBackendBoilerplate.Seeds.Example in seeders
    assert length(seeders) >= 2
  end
end
