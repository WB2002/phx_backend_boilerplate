defmodule PhxBackendBoilerplate.Jobs do
  @moduledoc """
  Thin wrapper around [Oban](https://hexdocs.pm/oban) for enqueueing background jobs.

  Prefer this module over calling `Oban.insert/1` directly from controllers so
  job args and request context stay consistent.

  ## Demo

      PhxBackendBoilerplate.Jobs.enqueue_demo(%{"message" => "hello", "work_ms" => 0})
  """

  import Ecto.Changeset

  alias PhxBackendBoilerplate.RequestContext
  alias PhxBackendBoilerplate.Workers.DemoJob

  @max_work_ms 2_000

  @doc """
  Enqueues a `DemoJob` with string-keyed args and current request tracing IDs.

  Accepts a map with `"message"` (required) and optional `"work_ms"`.
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
          |> put_request_context()

        args
        |> DemoJob.new()
        |> Oban.insert()

      changeset ->
        {:error, changeset}
    end
  end

  defp demo_changeset(attrs) do
    types = %{message: :string, work_ms: :integer}

    {%{message: nil, work_ms: nil}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required([:message])
    |> validate_length(:message, min: 1, max: 500)
    |> validate_number(:work_ms, greater_than_or_equal_to: 0, less_than_or_equal_to: @max_work_ms)
  end

  defp maybe_put_work_ms(args, nil), do: args

  defp maybe_put_work_ms(args, work_ms) when is_integer(work_ms),
    do: Map.put(args, "work_ms", work_ms)

  defp put_request_context(args) do
    ctx = RequestContext.current()

    args
    |> maybe_put("request_id", ctx.request_id)
    |> maybe_put("correlation_id", ctx.correlation_id)
  end

  defp maybe_put(args, _key, nil), do: args
  defp maybe_put(args, key, value) when is_binary(value), do: Map.put(args, key, value)

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {k, v}
      {"message", v} -> {:message, v}
      {"work_ms", v} -> {:work_ms, v}
      {k, v} when is_binary(k) -> {k, v}
    end)
  end
end
