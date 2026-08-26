defmodule PhxBackendBoilerplate.Recaptcha.Google do
  @moduledoc """
  Calls Google's reCAPTCHA siteverify API via `PhxBackendBoilerplate.HTTP`.
  """

  alias PhxBackendBoilerplate.HTTP

  @doc false
  def verify(token, opts) when is_binary(token) and is_list(opts) do
    secret = Keyword.get(opts, :secret_key)
    min_score = Keyword.get(opts, :min_score, 0.5)
    remote_ip = Keyword.get(opts, :remote_ip)
    url = Keyword.fetch!(opts, :siteverify_url)
    req_options = Keyword.get(opts, :req_options, [])

    if is_nil(secret) or secret == "" do
      {:error, :misconfigured}
    else
      form =
        [{"secret", secret}, {"response", token}]
        |> maybe_put_remoteip(remote_ip)

      case HTTP.post(
             url,
             Keyword.merge(req_options,
               form: form,
               headers: [{"content-type", "application/x-www-form-urlencoded"}]
             )
           ) do
        {:ok, %{status: 200, body: body}} ->
          interpret(body, min_score)

        {:ok, %{status: _status}} ->
          {:error, :http_error}

        {:error, :deadline_exceeded} ->
          {:error, :deadline_exceeded}

        {:error, _reason} ->
          {:error, :http_error}
      end
    end
  end

  defp maybe_put_remoteip(form, ip) when is_binary(ip) and ip != "",
    do: form ++ [{"remoteip", ip}]

  defp maybe_put_remoteip(form, _), do: form

  defp interpret(body, min_score) when is_map(body) do
    success? = Map.get(body, "success") == true
    score = Map.get(body, "score")

    cond do
      not success? ->
        {:error, :verification_failed}

      is_number(score) and score < min_score ->
        {:error, :low_score}

      true ->
        :ok
    end
  end

  defp interpret(body, min_score) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} -> interpret(map, min_score)
      {:error, _} -> {:error, :verification_failed}
    end
  end

  defp interpret(_, _), do: {:error, :verification_failed}
end
