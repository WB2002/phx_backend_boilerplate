defmodule PhxBackendBoilerplateWeb.Plugs.RateLimit do
  @moduledoc """
  Rate-limits requests using independent Hammer buckets per attribute.

  Options:

    * `:id` — string bucket id, e.g. `"demo_login"` (required)
    * `:scale` — window length in milliseconds (required)
    * `:limit` — max hits allowed in the window (required)
    * `:by` — list of attributes to check independently (default `[:ip]`)

  Allowed `:by` atoms: `:ip`, `:user_id`, `:fingerprint`, `:guest_id`, `:stripe_signature`.

  Each configured attribute gets its own Redis key shaped like
  `{id}:{attr}:{value}`. The request is denied if **any**
  bucket exceeds the limit. Missing optional attributes are skipped
  (`:fingerprint`, `:stripe_signature` when present).

  `:user_id` is read from `conn.assigns.current_user_id` when set (after
  `Authenticate`), otherwise from the `x-user-id` header for public demo buckets.
  `:guest_id` is read only from `conn.assigns.guest_id` — run
  `EnsureGuestId` on public pipelines before rate limiting.
  `:stripe_signature` uses `"absent"` when the header is missing (for
  cluster-wide unsigned flood protection) and is skipped when present.

  On deny, responds with `429`, a `Retry-After` header (seconds), and JSON:

      %{"errors" => %{"detail" => "Too Many Requests"}}

  Example:

      plug PhxBackendBoilerplateWeb.Plugs.RateLimit,
        id: "demo_public",
        scale: :timer.minutes(1),
        limit: 5,
        by: [:ip, :guest_id, :fingerprint]
  """

  import Plug.Conn

  alias PhxBackendBoilerplateWeb.ClientIp

  @behaviour Plug

  @allowed_by [:ip, :user_id, :fingerprint, :guest_id, :stripe_signature]

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    scale = Keyword.fetch!(opts, :scale)
    limit = Keyword.fetch!(opts, :limit)
    by = Keyword.get(opts, :by, [:ip])

    unless is_binary(id), do: raise(ArgumentError, ":id must be a string")

    unless is_integer(scale) and scale > 0,
      do: raise(ArgumentError, ":scale must be a positive integer")

    unless is_integer(limit) and limit > 0,
      do: raise(ArgumentError, ":limit must be a positive integer")

    unless is_list(by) and by != [] and Enum.all?(by, &(&1 in @allowed_by)),
      do: raise(ArgumentError, ":by must be a non-empty list of #{inspect(@allowed_by)}")

    %{id: id, scale: scale, limit: limit, by: by}
  end

  @impl true
  def call(conn, %{id: id, scale: scale, limit: limit, by: by}) do
    conn = fetch_cookies(conn)

    by
    |> Enum.reduce_while({:allow, conn}, fn attr, {:allow, acc} ->
      case resolve_value(acc, attr) do
        nil ->
          {:cont, {:allow, acc}}

        value ->
          key = "#{id}:#{attr}:#{value}"

          case PhxBackendBoilerplate.RateLimit.hit(key, scale, limit) do
            {:allow, _count} -> {:cont, {:allow, acc}}
            {:deny, retry_after_ms} -> {:halt, {:deny, acc, retry_after_ms}}
          end
      end
    end)
    |> case do
      {:allow, conn} ->
        conn

      {:deny, conn, retry_after_ms} ->
        deny(conn, retry_after_ms)
    end
  end

  defp resolve_value(conn, :ip), do: ClientIp.from_conn(conn)

  defp resolve_value(conn, :user_id) do
    conn.assigns
    |> Map.get(:current_user_id)
    |> present_or_nil()
    |> case do
      nil -> conn |> get_req_header("x-user-id") |> List.first() |> present_or_nil()
      user_id -> user_id
    end
  end

  defp resolve_value(conn, :fingerprint) do
    conn |> get_req_header("x-device-fingerprint") |> List.first() |> present_or_nil()
  end

  defp resolve_value(conn, :guest_id) do
    conn.assigns
    |> Map.get(:guest_id)
    |> present_or_nil()
  end

  defp resolve_value(conn, :stripe_signature) do
    case conn |> get_req_header("stripe-signature") |> List.first() |> present_or_nil() do
      nil -> "absent"
      _present -> nil
    end
  end

  defp deny(conn, retry_after_ms) do
    retry_after_seconds = max(div(retry_after_ms, 1000), 1)

    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after_seconds))
    |> put_resp_content_type("application/json")
    |> send_resp(429, Jason.encode!(%{errors: %{detail: "Too Many Requests"}}))
    |> halt()
  end

  defp present_or_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp present_or_nil(_), do: nil
end
