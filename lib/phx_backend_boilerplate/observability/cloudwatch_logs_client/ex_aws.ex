defmodule PhxBackendBoilerplate.Observability.CloudWatchLogsClient.ExAws do
  @moduledoc false
  @behaviour PhxBackendBoilerplate.Observability.CloudWatchLogsClient

  alias ExAws.CloudWatchLogs

  @impl true
  def create_log_group(log_group) do
    CloudWatchLogs.create_log_group(log_group)
    |> ExAws.request()
    |> normalize_create()
  end

  @impl true
  def create_log_stream(log_group, log_stream) do
    CloudWatchLogs.create_log_stream(log_group, log_stream)
    |> ExAws.request()
    |> normalize_create()
  end

  @impl true
  def put_log_events(log_group, log_stream, events, sequence_token) do
    opts = if sequence_token, do: [sequence_token: sequence_token], else: []

    case CloudWatchLogs.put_log_events(log_group, log_stream, events, opts) |> ExAws.request() do
      {:ok, body} when is_map(body) -> {:ok, Map.get(body, "nextSequenceToken")}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_create({:ok, _}), do: :ok

  defp normalize_create({:error, reason}) do
    if already_exists?(reason), do: :ok, else: {:error, reason}
  end

  defp already_exists?({"ResourceAlreadyExistsException", _}), do: true

  defp already_exists?({:http_error, 400, %{"__type" => "ResourceAlreadyExistsException"}}),
    do: true

  defp already_exists?({:http_error, 400, %{body: body}}) when is_binary(body) do
    String.contains?(body, "ResourceAlreadyExistsException")
  end

  defp already_exists?(body) when is_binary(body) do
    String.contains?(body, "ResourceAlreadyExistsException")
  end

  defp already_exists?(_), do: false
end
