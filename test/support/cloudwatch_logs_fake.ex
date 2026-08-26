defmodule PhxBackendBoilerplate.Observability.CloudWatchLogsClient.Fake do
  @moduledoc false
  @behaviour PhxBackendBoilerplate.Observability.CloudWatchLogsClient

  use Agent

  def start_link(opts \\ []) do
    Agent.start_link(fn -> %{calls: [], opts: Map.new(opts)} end, name: __MODULE__)
  end

  def stop do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      pid -> Agent.stop(pid)
    end
  end

  def calls do
    Agent.get(__MODULE__, & &1.calls)
  end

  @impl true
  def create_log_group(log_group) do
    record({:create_log_group, log_group})
    :ok
  end

  @impl true
  def create_log_stream(log_group, log_stream) do
    record({:create_log_stream, log_group, log_stream})
    :ok
  end

  @impl true
  def put_log_events(log_group, log_stream, events, sequence_token) do
    record({:put_log_events, log_group, log_stream, events, sequence_token})
    {:ok, "token-1"}
  end

  defp record(call) do
    Agent.update(__MODULE__, fn state ->
      %{state | calls: [call | state.calls]}
    end)
  end
end
