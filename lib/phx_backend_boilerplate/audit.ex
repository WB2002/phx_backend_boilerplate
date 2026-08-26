defmodule PhxBackendBoilerplate.Audit do
  @moduledoc """
  Append-only audit logging.

  Prefer `log/1` for writes. There is no update or delete API — the database
  rejects mutations on `audit.audit_logs`.

  Do not put secrets or credentials in `metadata`.
  """

  alias PhxBackendBoilerplate.Audit.Log
  alias PhxBackendBoilerplate.Repo
  alias PhxBackendBoilerplate.RequestContext

  @context_fields [:actor_id, :request_id, :correlation_id]

  @doc """
  Inserts an audit log.

  When `actor_id`, `request_id`, or `correlation_id` are omitted, values are
  taken from `RequestContext.current/0` (`user_id` → `actor_id`). Explicit
  attrs win over context.
  """
  @spec log(map()) :: {:ok, Log.t()} | {:error, Ecto.Changeset.t()}
  def log(attrs) when is_map(attrs) do
    attrs
    |> normalize_attrs()
    |> merge_request_context()
    |> then(fn attrs ->
      %Log{}
      |> Log.changeset(attrs)
      |> Repo.insert()
    end)
  end

  @attr_keys ~w(action resource_type resource_id actor_id request_id correlation_id metadata)a

  defp normalize_attrs(attrs) do
    Map.new(attrs, fn
      {k, v} when is_atom(k) -> {k, v}
      {k, v} when is_binary(k) -> {known_attr_key(k), v}
    end)
  end

  defp known_attr_key(key) do
    Enum.find(@attr_keys, fn atom -> Atom.to_string(atom) == key end) ||
      raise ArgumentError, "unknown audit attr key: #{inspect(key)}"
  end

  defp merge_request_context(attrs) do
    ctx = RequestContext.current()

    context_values = %{
      actor_id: ctx.user_id,
      request_id: ctx.request_id,
      correlation_id: ctx.correlation_id
    }

    Enum.reduce(@context_fields, attrs, fn field, acc ->
      if Map.has_key?(acc, field) do
        acc
      else
        case Map.get(context_values, field) do
          nil -> acc
          value -> Map.put(acc, field, value)
        end
      end
    end)
  end
end
