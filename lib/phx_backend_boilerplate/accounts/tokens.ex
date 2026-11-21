defmodule PhxBackendBoilerplate.Accounts.Tokens do
  @moduledoc """
  Signs and verifies access and refresh JWTs with separate HMAC secrets.

  Both token types carry `jti` (session id) and `sub` (user id). Refresh tokens
  also carry `rti` (refresh token id) for rotation and reuse detection. Tokens
  are never persisted — the session row is the source of truth.
  """

  alias PhxBackendBoilerplate.Accounts.Session

  @access_typ "access"
  @refresh_typ "refresh"

  @doc """
  Returns a signed access JWT for the given user and session.
  """
  @spec generate_access_token(String.t(), String.t()) :: String.t()
  def generate_access_token(user_id, session_id)
      when is_binary(user_id) and is_binary(session_id) do
    now = DateTime.utc_now(:second)
    exp = DateTime.add(now, access_ttl_seconds(), :second)

    extra_claims = %{
      "sub" => user_id,
      "jti" => session_id,
      "typ" => @access_typ,
      "iat" => DateTime.to_unix(now),
      "exp" => DateTime.to_unix(exp)
    }

    {:ok, token, _} =
      Joken.encode_and_sign(extra_claims, access_signer())

    token
  end

  @doc """
  Returns a signed refresh JWT whose `exp` matches the session inactivity deadline.
  """
  @spec generate_refresh_token(String.t(), Session.t()) :: String.t()
  def generate_refresh_token(user_id, %Session{
        id: session_id,
        expires_at: expires_at,
        refresh_token_id: refresh_token_id
      })
      when is_binary(user_id) and is_binary(session_id) and is_binary(refresh_token_id) do
    now = DateTime.utc_now(:second)

    extra_claims = %{
      "sub" => user_id,
      "jti" => session_id,
      "rti" => refresh_token_id,
      "typ" => @refresh_typ,
      "iat" => DateTime.to_unix(now),
      "exp" => DateTime.to_unix(expires_at, :second)
    }

    {:ok, token, _} =
      Joken.encode_and_sign(extra_claims, refresh_signer())

    token
  end

  @doc """
  Verifies an access JWT and returns claims on success.
  """
  @spec verify_access(String.t()) :: {:ok, map()} | {:error, atom()}
  def verify_access(token) when is_binary(token) do
    with {:ok, claims} <- Joken.verify(token, access_signer()),
         :ok <- validate_typ(claims, @access_typ),
         :ok <- validate_time_claims(claims),
         :ok <- validate_access_claims(claims) do
      {:ok, claims}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, :invalid_token}
    end
  end

  @doc """
  Verifies a refresh JWT and returns claims on success.
  """
  @spec verify_refresh(String.t()) :: {:ok, map()} | {:error, atom()}
  def verify_refresh(token) when is_binary(token) do
    with {:ok, claims} <- Joken.verify(token, refresh_signer()),
         :ok <- validate_typ(claims, @refresh_typ),
         :ok <- validate_time_claims(claims),
         :ok <- validate_refresh_claims(claims) do
      {:ok, claims}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, :invalid_token}
    end
  end

  @doc """
  Returns access token TTL in seconds (for JSON `expires_in`).
  """
  @spec access_ttl_seconds() :: non_neg_integer()
  def access_ttl_seconds do
    accounts_config()
    |> Keyword.fetch!(:access_ttl)
    |> div(1_000)
  end

  defp access_signer do
    secret = Keyword.fetch!(accounts_config(), :access_secret)
    Joken.Signer.create("HS256", secret)
  end

  defp refresh_signer do
    secret = Keyword.fetch!(accounts_config(), :refresh_secret)
    Joken.Signer.create("HS256", secret)
  end

  defp accounts_config do
    Application.fetch_env!(:phx_backend_boilerplate, PhxBackendBoilerplate.Accounts)
  end

  defp validate_typ(%{"typ" => typ}, expected) when typ == expected, do: :ok
  defp validate_typ(_claims, _expected), do: :error

  defp validate_time_claims(claims) do
    now = DateTime.utc_now(:second) |> DateTime.to_unix()

    with :ok <- validate_nbf(claims, now),
         :ok <- validate_exp(claims, now) do
      :ok
    else
      :error -> :error
    end
  end

  defp validate_nbf(%{"nbf" => nbf}, now) when is_integer(nbf) and nbf > now, do: :error
  defp validate_nbf(%{"nbf" => nbf}, _now) when is_integer(nbf), do: :ok
  defp validate_nbf(_claims, _now), do: :ok

  defp validate_exp(%{"exp" => exp}, now) when is_integer(exp) and exp > now, do: :ok
  defp validate_exp(_claims, _now), do: :error

  defp validate_access_claims(%{"sub" => sub, "jti" => jti})
       when is_binary(sub) and is_binary(jti),
       do: :ok

  defp validate_access_claims(_claims), do: :error

  defp validate_refresh_claims(%{"sub" => sub, "jti" => jti, "rti" => rti})
       when is_binary(sub) and is_binary(jti) and is_binary(rti),
       do: :ok

  defp validate_refresh_claims(_claims), do: :error
end
