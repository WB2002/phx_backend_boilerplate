defmodule PhxBackendBoilerplate.Files.Scanner.Fake do
  @moduledoc false
  @behaviour PhxBackendBoilerplate.Files.Scanner

  use Agent

  def start_link(opts \\ []) do
    Agent.start_link(fn -> %{result: Keyword.get(opts, :result, :clean), calls: []} end,
      name: __MODULE__
    )
  end

  def stop do
    case Process.whereis(__MODULE__) do
      nil ->
        :ok

      pid ->
        try do
          Agent.stop(pid)
        catch
          :exit, _ -> :ok
        end
    end
  end

  def set_result(scan_outcome) do
    ensure_started()
    Agent.update(__MODULE__, &Map.put(&1, :result, scan_outcome))
  end

  def calls do
    ensure_started()
    Agent.get(__MODULE__, & &1.calls)
  end

  @impl true
  def scan_file(path) do
    ensure_started()

    Agent.get_and_update(__MODULE__, fn state ->
      state = %{state | calls: [{:scan_file, path} | state.calls]}
      {state.result, state}
    end)
  end

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        {:ok, _} = start_link()
        :ok

      _pid ->
        :ok
    end
  end
end
