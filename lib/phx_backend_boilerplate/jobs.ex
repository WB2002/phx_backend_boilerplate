defmodule PhxBackendBoilerplate.Jobs do
  @moduledoc """
  Thin wrapper around [Oban](https://hexdocs.pm/oban) for enqueueing background jobs.

  Prefer this module over calling `Oban.insert/1` directly from controllers so
  job args and request context stay consistent.

  ## Demo

      PhxBackendBoilerplate.Jobs.enqueue_demo(%{"message" => "hello", "work_ms" => 0})

      PhxBackendBoilerplate.Jobs.enqueue_demo(%{
        "message" => "hello",
        "notify_slack" => true,
        "slack_channel" => "C0123456789"
      })
  """

  import Ecto.Changeset

  alias PhxBackendBoilerplate.RequestContext
  alias PhxBackendBoilerplate.Workers.DemoJob

  @max_work_ms 2_000

  @doc """
  Enqueues a `DemoJob` with string-keyed args and current request tracing IDs.

  Accepts a map with `"message"` (required), optional `"work_ms"`, and optional
  Slack notify flags `"notify_slack"` / `"slack_channel"`.
  """
  @spec enqueue_demo(map()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_demo(attrs) when is_map(attrs) do
    attrs
    |> atomize_keys()
    |> demo_changeset()
    |> case do
      %{valid?: true} = changeset ->
        changes = apply_changes(changeset)

        args =
          %{}
          |> Map.put("message", changes.message)
          |> maybe_put_work_ms(changes.work_ms)
          |> maybe_put_slack(changes)
          |> put_request_context()

        args
        |> DemoJob.new()
        |> Oban.insert()

      changeset ->
        {:error, changeset}
    end
  end

  defp demo_changeset(attrs) do
    types = %{
      message: :string,
      work_ms: :integer,
      notify_slack: :boolean,
      slack_channel: :string
    }

    {%{message: nil, work_ms: nil, notify_slack: false, slack_channel: nil}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required([:message])
    |> validate_length(:message, min: 1, max: 500)
    |> validate_number(:work_ms, greater_than_or_equal_to: 0, less_than_or_equal_to: @max_work_ms)
    |> validate_length(:slack_channel, max: 100)
    |> validate_slack_channel_when_notifying()
  end

  defp validate_slack_channel_when_notifying(changeset) do
    notify? = get_field(changeset, :notify_slack) == true
    channel = get_field(changeset, :slack_channel)
    default = slack_default_channel()

    cond do
      not notify? ->
        changeset

      is_binary(channel) and channel != "" ->
        changeset

      is_binary(default) and default != "" ->
        changeset

      true ->
        add_error(
          changeset,
          :slack_channel,
          "can't be blank when notify_slack is true and SLACK_DEFAULT_CHANNEL is unset"
        )
    end
  end

  defp maybe_put_work_ms(args, nil), do: args

  defp maybe_put_work_ms(args, work_ms) when is_integer(work_ms),
    do: Map.put(args, "work_ms", work_ms)

  defp maybe_put_slack(args, %{notify_slack: true} = changes) do
    args = Map.put(args, "notify_slack", true)

    case changes.slack_channel do
      channel when is_binary(channel) and channel != "" ->
        Map.put(args, "slack_channel", channel)

      _ ->
        args
    end
  end

  defp maybe_put_slack(args, _), do: args

  defp put_request_context(args) do
    ctx = RequestContext.current()

    args
    |> maybe_put("request_id", ctx.request_id)
    |> maybe_put("correlation_id", ctx.correlation_id)
  end

  defp maybe_put(args, _key, nil), do: args
  defp maybe_put(args, key, value) when is_binary(value), do: Map.put(args, key, value)

  defp slack_default_channel do
    Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Integrations.Slack, [])
    |> Keyword.get(:default_channel)
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {k, v}
      {"message", v} -> {:message, v}
      {"work_ms", v} -> {:work_ms, v}
      {"notify_slack", v} -> {:notify_slack, v}
      {"slack_channel", v} -> {:slack_channel, v}
      {k, v} when is_binary(k) -> {k, v}
    end)
  end
end
