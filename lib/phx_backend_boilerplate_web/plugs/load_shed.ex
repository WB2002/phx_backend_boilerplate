defmodule PhxBackendBoilerplateWeb.Plugs.LoadShed do
  @moduledoc """
  Adaptive concurrency / load shedding via [Regulator](https://hexdocs.pm/regulator).

  Sits **after** rate limiting (`PhxBackendBoilerplateWeb.Plugs.RateLimit`) and
  **before** expensive controller work. Hammer answers "is this client allowed?"
  (429); this plug answers "can the system handle another concurrent request?"
  (503 when dropped).

  Options:

    * `:regulator` — atom name installed by `PhxBackendBoilerplate.LoadShed` (required)
    * `:error_code` — status when the concurrency limit is reached (default `503`)
    * `:error_detail` — JSON `errors.detail` string (default `"Service Unavailable"`)

  On allow, registers `before_send` to check the token back in:

    * status `401` → `Regulator.ignore/1`
    * status `>= 500` → `Regulator.error/1`
    * otherwise → `Regulator.ok/1`

  Example:

      plug PhxBackendBoilerplateWeb.Plugs.LoadShed, regulator: :demo_expensive
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts) do
    regulator = Keyword.fetch!(opts, :regulator)
    error_code = Keyword.get(opts, :error_code, 503)
    error_detail = Keyword.get(opts, :error_detail, "Service Unavailable")

    unless is_atom(regulator),
      do: raise(ArgumentError, ":regulator must be an atom")

    unless is_integer(error_code) and error_code >= 100 and error_code < 600,
      do: raise(ArgumentError, ":error_code must be a valid HTTP status")

    unless is_binary(error_detail),
      do: raise(ArgumentError, ":error_detail must be a binary")

    %{regulator: regulator, error_code: error_code, error_detail: error_detail}
  end

  @impl true
  def call(conn, opts) do
    case Regulator.ask(opts.regulator) do
      :dropped ->
        deny(conn, opts)

      {:ok, ctx} ->
        register_before_send(conn, fn conn ->
          cond do
            conn.status == 401 ->
              Regulator.ignore(ctx)

            is_integer(conn.status) and conn.status >= 500 ->
              Regulator.error(ctx)

            true ->
              Regulator.ok(ctx)
          end

          conn
        end)
    end
  end

  defp deny(conn, %{error_code: code, error_detail: detail}) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(code, Jason.encode!(%{errors: %{detail: detail}}))
    |> halt()
  end
end
