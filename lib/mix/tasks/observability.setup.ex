defmodule Mix.Tasks.Observability.Setup do
  @shortdoc "Create CloudWatch log group (LocalStack or AWS)"
  @moduledoc """
  Ensures the CloudWatch log group from config exists.

  Typical LocalStack usage:

      export AWS_ENDPOINT_URL=http://localhost:4566
      export AWS_ACCESS_KEY_ID=test
      export AWS_SECRET_ACCESS_KEY=test
      export CLOUDWATCH_LOG_GROUP=/phx-backend-boilerplate/dev
      mix observability.setup
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    opts =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Observability, [])

    log_group =
      opts
      |> Keyword.get(:cloudwatch_logs, [])
      |> Keyword.fetch!(:log_group)

    Mix.shell().info("Ensuring CloudWatch log group: #{log_group}")

    case PhxBackendBoilerplate.Observability.CloudWatchLogsClient.create_log_group(log_group) do
      :ok ->
        Mix.shell().info("OK")

      {:error, reason} ->
        Mix.raise("Failed to create log group: #{inspect(reason)}")
    end
  end
end
