defmodule PhxBackendBoilerplate.Observability.CloudWatchLogsClient do
  @moduledoc """
  Thin wrapper around ExAws CloudWatch Logs for the Logger handler.

  Swap via `config :phx_backend_boilerplate, :cloudwatch_logs_client, Module`
  in tests (e.g. Mox).
  """

  @callback create_log_group(log_group :: String.t()) :: :ok | {:error, term()}
  @callback create_log_stream(log_group :: String.t(), log_stream :: String.t()) ::
              :ok | {:error, term()}
  @callback put_log_events(
              log_group :: String.t(),
              log_stream :: String.t(),
              events :: [map()],
              sequence_token :: String.t() | nil
            ) :: {:ok, String.t() | nil} | {:error, term()}

  def create_log_group(log_group), do: impl().create_log_group(log_group)

  def create_log_stream(log_group, log_stream),
    do: impl().create_log_stream(log_group, log_stream)

  def put_log_events(log_group, log_stream, events, sequence_token),
    do: impl().put_log_events(log_group, log_stream, events, sequence_token)

  defp impl do
    Application.get_env(
      :phx_backend_boilerplate,
      :cloudwatch_logs_client,
      PhxBackendBoilerplate.Observability.CloudWatchLogsClient.ExAws
    )
  end
end
