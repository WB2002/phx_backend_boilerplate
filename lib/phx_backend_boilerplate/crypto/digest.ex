defmodule PhxBackendBoilerplate.Crypto.Digest do
  @moduledoc """
  One-way digests via Argon2id (PHC string format).

  Suitable for secrets that must be verified later without recovery.
  Names are intentionally generic — not tied to any particular secret type.
  """

  @doc """
  Digests `plaintext` with a random salt.

  Returns an Argon2id PHC string (includes salt and parameters).
  """
  @spec digest(binary(), keyword()) :: String.t()
  def digest(plaintext, opts \\ []) when is_binary(plaintext) do
    Argon2.hash_pwd_salt(plaintext, opts)
  end

  @doc """
  Returns `true` when `plaintext` matches `stored` digest.

  Uses a constant-time comparison via Argon2.
  """
  @spec verify(binary(), String.t()) :: boolean()
  def verify(plaintext, stored) when is_binary(plaintext) and is_binary(stored) do
    Argon2.verify_pass(plaintext, stored)
  end

  @doc """
  Runs a dummy verification for timing parity when no stored digest exists
  (e.g. unknown account). Always returns `false`.
  """
  @spec dummy_verify() :: false
  def dummy_verify do
    Argon2.no_user_verify()
    false
  end
end
