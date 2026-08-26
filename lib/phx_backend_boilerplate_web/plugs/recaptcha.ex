defmodule PhxBackendBoilerplateWeb.Plugs.Recaptcha do
  @moduledoc """
  Verifies a reCAPTCHA v3 token before the controller runs.

  Reads the token from (first match wins):

  * JSON / params key `"recaptcha_token"`
  * Form key `"g-recaptcha-response"`

  On failure responds with `403` and:

      %{"errors" => %{"detail" => "reCAPTCHA verification failed"}}

  Missing tokens fail closed unless `PhxBackendBoilerplate.Recaptcha` is
  configured with `skip: true`.
  """

  import Plug.Conn

  alias PhxBackendBoilerplate.Recaptcha

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    token = extract_token(conn)
    remote_ip = client_ip(conn)

    case Recaptcha.verify(token, remote_ip: remote_ip) do
      :ok ->
        conn

      {:error, _reason} ->
        deny(conn)
    end
  end

  defp extract_token(conn) do
    params = conn.params || %{}

    Map.get(params, "recaptcha_token") ||
      Map.get(params, "g-recaptcha-response") ||
      Map.get(params, :recaptcha_token) ||
      Map.get(params, :g_recaptcha_response)
  end

  defp client_ip(conn) do
    forwarded =
      conn
      |> get_req_header("x-forwarded-for")
      |> List.first()

    cond do
      is_binary(forwarded) and String.trim(forwarded) != "" ->
        forwarded
        |> String.split(",", trim: true)
        |> List.first()
        |> String.trim()

      is_tuple(conn.remote_ip) ->
        conn.remote_ip |> :inet.ntoa() |> to_string()

      true ->
        nil
    end
  end

  defp deny(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(403, Jason.encode!(%{errors: %{detail: "reCAPTCHA verification failed"}}))
    |> halt()
  end
end
