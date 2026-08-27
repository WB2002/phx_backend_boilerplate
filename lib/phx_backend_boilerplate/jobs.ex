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
  import Ecto.Query

  alias PhxBackendBoilerplate.RequestContext
  alias PhxBackendBoilerplate.Repo
  alias PhxBackendBoilerplate.Workers.DemoJob
  alias PhxBackendBoilerplate.Workers.StripeWebhookJob

  @max_work_ms 2_000
  @max_demo_queue_depth 100
  @demo_active_states ~w(available scheduled executing retryable)

  @doc """
  Enqueues a `StripeWebhookJob` with only the Stripe event id.

  The worker fetches the full payload from Stripe. Uses `stripe_event_id`
  for Oban unique job deduplication.
  """
  @spec enqueue_stripe_webhook(String.t() | map()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_stripe_webhook(event_id) when is_binary(event_id) do
    %{"stripe_event_id" => event_id}
    |> StripeWebhookJob.new()
    |> Oban.insert()
  end

  def enqueue_stripe_webhook(%{"id" => event_id}) when is_binary(event_id) do
    enqueue_stripe_webhook(event_id)
  end

  def enqueue_stripe_webhook(_event), do: {:error, invalid_event_changeset()}

  defp invalid_event_changeset do
    {%{}, %{event: :string}}
    |> cast(%{}, [:event])
    |> add_error(:event, "invalid stripe event")
  end

  @doc """
  Enqueues a `DemoJob` with string-keyed args and current request tracing IDs.

  Accepts a map with `"message"` (required), optional `"work_ms"`, and optional
  Slack notify flags `"notify_slack"` / `"slack_channel"`.

  Returns `{:error, :queue_full}` when too many DemoJobs are already active,
  or `{:error, :unique}` when Oban unique rejects a duplicate message within
  the uniqueness window.
  """
  @spec enqueue_demo(map()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t() | :queue_full | :unique}
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

        with :ok <- ensure_demo_queue_capacity() do
          insert_demo_job(args)
        end

      changeset ->
        {:error, changeset}
    end
  end

  defp ensure_demo_queue_capacity do
    count =
      Oban.Job
      |> where([j], j.worker == ^Oban.Worker.to_string(DemoJob))
      |> where([j], j.state in ^@demo_active_states)
      |> Repo.aggregate(:count)

    if count >= @max_demo_queue_depth do
      {:error, :queue_full}
    else
      :ok
    end
  end

  defp insert_demo_job(args) do
    case args |> DemoJob.new() |> Oban.insert() do
      {:ok, %Oban.Job{conflict?: true}} ->
        {:error, :unique}

      {:ok, job} ->
        {:ok, job}

      {:error, %Ecto.Changeset{} = changeset} ->
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
