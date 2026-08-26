defmodule PhxBackendBoilerplate.RequestContext do
  @moduledoc """
  Process-local request tracing context: `request_id`, `correlation_id`, and
  optional `user_id`.

  Installed at the Phoenix edge after `Plug.RequestId` via
  `PhxBackendBoilerplateWeb.Plugs.RequestContext`. Logger metadata is kept in
  sync so logs, Ecto telemetry, and outbound HTTP can share the same IDs.

  On the wire:

    * `x-request-id` — per-hop id (from `Plug.RequestId`)
    * `x-correlation-id` — journey id (honored if valid, else generated)

  `user_id` is never echoed as a request/response header; set it from trusted
  auth assigns or `put_user_id/1`.
  """

  @process_key :phx_backend_boilerplate_request_context
  @correlation_header "x-correlation-id"
  @request_id_header "x-request-id"
  @max_correlation_id_length 128
  @correlation_id_pattern ~r/\A[A-Za-z0-9._-]{1,128}\z/

  @empty %{request_id: nil, correlation_id: nil, user_id: nil}

  @doc """
  Returns the current context map. Missing keys are `nil`.
  """
  def current do
    case Process.get(@process_key) do
      %{request_id: _, correlation_id: _, user_id: _} = ctx -> ctx
      _ -> @empty
    end
  end

  @doc """
  Installs context from `conn` after `Plug.RequestId`.

  Reads Logger `:request_id`, resolves `x-correlation-id` (or generates a UUID),
  and optional `conn.assigns.current_user_id`. Updates process dictionary and
  Logger metadata.
  """
  def start_from_conn(%Plug.Conn{} = conn) do
    request_id = Keyword.get(Logger.metadata(), :request_id)
    correlation_id = resolve_correlation_id(conn.req_headers)
    user_id = assign_user_id(conn)

    put(%{
      request_id: request_id,
      correlation_id: correlation_id,
      user_id: user_id
    })
  end

  @doc """
  Merges `user_id` into the current context and Logger metadata.
  """
  def put_user_id(user_id) when is_binary(user_id) do
    put(%{current() | user_id: user_id})
  end

  def put_user_id(nil) do
    put(%{current() | user_id: nil})
  end

  @doc """
  Headers to forward on outbound calls: `x-request-id` and/or
  `x-correlation-id`. Omits nil values. Does not include `user_id`.
  """
  def propagation_headers do
    ctx = current()

    []
    |> maybe_header(@request_id_header, ctx.request_id)
    |> maybe_header(@correlation_header, ctx.correlation_id)
  end

  @doc """
  Runs `fun` with `ctx` installed (or cleared if `nil`), restoring previous
  process context and Logger metadata afterward.
  """
  def with(ctx, fun) when is_function(fun, 0) do
    previous_ctx = Process.get(@process_key)
    previous_meta = Logger.metadata()

    try do
      case ctx do
        nil -> clear()
        map when is_map(map) -> put(normalize(map))
      end

      fun.()
    after
      restore(previous_ctx, previous_meta)
    end
  end

  @doc """
  Like `Task.async/1`, but installs the parent's context and Logger metadata
  keys (`:request_id`, `:correlation_id`, `:user_id`) in the child.
  """
  def async(fun) when is_function(fun, 0) do
    ctx = current()
    meta = Logger.metadata()

    Task.async(fn ->
      __MODULE__.with(ctx, fn ->
        Logger.metadata(
          request_id: Keyword.get(meta, :request_id),
          correlation_id: Keyword.get(meta, :correlation_id),
          user_id: Keyword.get(meta, :user_id)
        )

        fun.()
      end)
    end)
  end

  @doc """
  Parses a valid correlation id from Plug/Req-style headers, or `nil`.
  """
  def correlation_id_from_headers(headers) when is_list(headers) do
    values =
      for {name, value} <- headers,
          normalize_header_name(name) == @correlation_header,
          do: value

    case values do
      [single] -> parse_correlation_id(single)
      _ -> nil
    end
  end

  def correlation_id_from_headers(headers) when is_map(headers) do
    headers
    |> Enum.flat_map(fn {name, value} ->
      Enum.map(List.wrap(value), &{name, &1})
    end)
    |> correlation_id_from_headers()
  end

  defp resolve_correlation_id(headers) do
    case correlation_id_from_headers(headers) do
      nil -> Ecto.UUID.generate()
      id -> id
    end
  end

  defp assign_user_id(%Plug.Conn{assigns: assigns}) do
    case Map.get(assigns, :current_user_id) do
      id when is_binary(id) and id != "" -> id
      _ -> nil
    end
  end

  defp put(%{request_id: _, correlation_id: _, user_id: _} = ctx) do
    Process.put(@process_key, ctx)

    Logger.metadata(
      request_id: ctx.request_id,
      correlation_id: ctx.correlation_id,
      user_id: ctx.user_id
    )

    :ok
  end

  defp clear do
    Process.delete(@process_key)

    Logger.metadata(
      request_id: nil,
      correlation_id: nil,
      user_id: nil
    )

    :ok
  end

  defp restore(nil, previous_meta) do
    Process.delete(@process_key)
    restore_logger_metadata(previous_meta)
  end

  defp restore(ctx, previous_meta) when is_map(ctx) do
    Process.put(@process_key, normalize(ctx))
    restore_logger_metadata(previous_meta)
  end

  defp restore_logger_metadata(previous_meta) do
    Logger.reset_metadata(previous_meta)
  end

  defp normalize(map) when is_map(map) do
    %{
      request_id: Map.get(map, :request_id),
      correlation_id: Map.get(map, :correlation_id),
      user_id: Map.get(map, :user_id)
    }
  end

  defp maybe_header(headers, _name, nil), do: headers
  defp maybe_header(headers, name, value) when is_binary(value), do: headers ++ [{name, value}]

  defp parse_correlation_id(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed != "" and byte_size(trimmed) <= @max_correlation_id_length and
         Regex.match?(@correlation_id_pattern, trimmed) do
      trimmed
    else
      nil
    end
  end

  defp parse_correlation_id(_), do: nil

  defp normalize_header_name(name) when is_binary(name), do: String.downcase(name)

  defp normalize_header_name(name) when is_atom(name),
    do: name |> Atom.to_string() |> String.downcase()

  defp normalize_header_name(name), do: name |> to_string() |> String.downcase()
end
