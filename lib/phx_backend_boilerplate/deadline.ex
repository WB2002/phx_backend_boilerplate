defmodule PhxBackendBoilerplate.Deadline do
  @moduledoc """
  Request time budget stored as a process-local monotonic absolute deadline.

  On the wire, remaining budget is propagated as `x-request-timeout-ms`.
  Wall-clock time is never used for enforcement or propagation.
  """

  @process_key :phx_backend_boilerplate_request_deadline
  @header "x-request-timeout-ms"

  @doc """
  Starts a deadline `timeout_ms` from now (monotonic).
  """
  def start(timeout_ms) when is_integer(timeout_ms) and timeout_ms >= 0 do
    start_at(System.monotonic_time(:millisecond) + timeout_ms)
  end

  @doc """
  Installs an absolute monotonic deadline (same unit as
  `System.monotonic_time(:millisecond)`).
  """
  def start_at(monotonic_ms) when is_integer(monotonic_ms) do
    Process.put(@process_key, monotonic_ms)
    :ok
  end

  @doc """
  Returns the absolute monotonic deadline, or `nil` if unset.
  """
  def current do
    Process.get(@process_key)
  end

  @doc """
  Remaining milliseconds. `nil` if unset; `0` if expired (never negative).
  """
  def remaining do
    case current() do
      nil ->
        nil

      deadline ->
        max(deadline - System.monotonic_time(:millisecond), 0)
    end
  end

  @doc """
  `false` if unset; otherwise whether the deadline has already passed.
  """
  def expired? do
    case current() do
      nil -> false
      deadline -> deadline <= System.monotonic_time(:millisecond)
    end
  end

  @doc """
  Runs `fun` with `deadline` installed (or cleared if `nil`), then restores
  the previous deadline. Must run in the process that should carry the budget
  (e.g. inside a Task body, not the parent).
  """
  def with(deadline, fun) when is_function(fun, 0) do
    previous = current()

    try do
      case deadline do
        nil -> clear()
        ms when is_integer(ms) -> start_at(ms)
      end

      fun.()
    after
      restore_at(previous)
    end
  end

  @doc """
  Like `Task.async/1`, but captures the parent's deadline and installs it in
  the child via `with/2`.
  """
  def async(fun) when is_function(fun, 0) do
    deadline = current()
    Task.async(fn -> __MODULE__.with(deadline, fun) end)
  end

  @doc """
  Headers to forward remaining budget: `[{"x-request-timeout-ms", ms}]` or `[]`.
  """
  def propagation_headers do
    case remaining() do
      nil -> []
      ms -> [{@header, Integer.to_string(ms)}]
    end
  end

  @doc """
  Parses remaining budget from Plug/Req-style headers. Returns a non-negative
  integer or `nil` if absent/malformed.
  """
  def from_headers(headers) when is_list(headers) do
    values =
      for {name, value} <- headers,
          normalize_header_name(name) == @header,
          do: value

    case values do
      [] ->
        nil

      [single] ->
        parse_timeout_ms(single)

      _many ->
        nil
    end
  end

  def from_headers(headers) when is_map(headers) do
    headers
    |> Enum.flat_map(fn {name, value} ->
      values = List.wrap(value)
      Enum.map(values, &{name, &1})
    end)
    |> from_headers()
  end

  @doc """
  Installs a deadline from `conn` headers, capped by `timeout_ms`.

  Uses a single monotonic read. Malformed/absent header → full `timeout_ms`.
  Valid `0` → already expired (`start_at(mono_now)`).
  """
  def start_from_conn(conn, timeout_ms)
      when is_integer(timeout_ms) and timeout_ms >= 0 do
    mono_now = System.monotonic_time(:millisecond)

    case from_headers(conn.req_headers) do
      nil ->
        start_at(mono_now + timeout_ms)

      remaining_ms ->
        effective = min(remaining_ms, timeout_ms)
        start_at(mono_now + effective)
    end
  end

  defp clear do
    Process.delete(@process_key)
    :ok
  end

  defp restore_at(nil), do: clear()
  defp restore_at(ms) when is_integer(ms), do: start_at(ms)

  defp normalize_header_name(name) when is_binary(name), do: String.downcase(name)

  defp normalize_header_name(name) when is_atom(name),
    do: name |> Atom.to_string() |> String.downcase()

  defp normalize_header_name(name), do: to_string(name) |> String.downcase()

  defp parse_timeout_ms(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp parse_timeout_ms(value) when is_integer(value) and value >= 0, do: value
  defp parse_timeout_ms(_), do: nil
end
