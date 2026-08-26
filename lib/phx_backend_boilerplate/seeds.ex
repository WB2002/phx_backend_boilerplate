defmodule PhxBackendBoilerplate.Seeds do
  @moduledoc """
  Ordered, versioned seeder runner.

  Seeders are registered explicitly in `@seeders`. A seeder runs when it has
  never been recorded, or when its `version/0` differs from the stored
  version. Same version → skip.

  Invoke via `mix seed` or `priv/repo/seeds.exs` (used by `mix ecto.setup`).
  """

  alias PhxBackendBoilerplate.Repo
  alias PhxBackendBoilerplate.Seeds.{DemoPreviewFlag, Example, Record}

  @seeders [DemoPreviewFlag, Example]

  @type result :: %{ran: [module()], skipped: [module()]}

  @doc "Registered seeders in run order."
  @spec seeders() :: [module()]
  def seeders, do: @seeders

  @doc "Runs all registered seeders."
  @spec run() :: {:ok, result()} | {:error, {module(), term()}}
  def run, do: run(@seeders)

  @doc """
  Runs the given seeder modules in order.

  Used by tests to inject fakes without hitting FunWithFlags.
  """
  @spec run([module()]) :: {:ok, result()} | {:error, {module(), term()}}
  def run(modules) when is_list(modules) do
    Enum.reduce_while(modules, {:ok, %{ran: [], skipped: []}}, fn module, {:ok, acc} ->
      case maybe_run(module) do
        :ran ->
          {:cont, {:ok, %{acc | ran: [module | acc.ran]}}}

        :skipped ->
          {:cont, {:ok, %{acc | skipped: [module | acc.skipped]}}}

        {:error, reason} ->
          {:halt, {:error, {module, reason}}}
      end
    end)
    |> case do
      {:ok, %{ran: ran, skipped: skipped}} ->
        {:ok, %{ran: Enum.reverse(ran), skipped: Enum.reverse(skipped)}}

      {:error, _} = err ->
        err
    end
  end

  defp maybe_run(module) do
    name = Atom.to_string(module)
    desired = module.version()
    record = Repo.get_by(Record, name: name)

    if record && record.version == desired do
      :skipped
    else
      apply_seeder(module, name, desired, record)
    end
  end

  defp apply_seeder(module, name, desired, record) do
    case Repo.transaction(fn ->
           case module.run() do
             :ok ->
               persist_record!(name, desired, record)
               :ran

             {:error, reason} ->
               Repo.rollback(reason)

             other ->
               Repo.rollback({:invalid_return, other})
           end
         end) do
      {:ok, :ran} -> :ran
      {:error, reason} -> {:error, reason}
    end
  rescue
    error ->
      {:error, error}
  end

  defp persist_record!(name, desired, nil) do
    %Record{}
    |> Record.changeset(%{name: name, version: desired})
    |> Repo.insert!()
  end

  defp persist_record!(_name, desired, %Record{} = record) do
    record
    |> Record.changeset(%{version: desired})
    |> Repo.update!()
  end
end
