defmodule PhxBackendBoilerplate.Crypto.Digest do
  @moduledoc """
  One-way digests via Argon2id (PHC string format).

  Suitable for secrets that must be verified later without recovery.
  Names are intentionally generic — not tied to any particular secret type.
  """

  @max_plaintext_bytes 72

  @doc """
  Maximum password/plaintext size accepted before Argon2 (bytes).
  """
  @spec max_plaintext_bytes() :: pos_integer()
  def max_plaintext_bytes, do: @max_plaintext_bytes

  @doc """
  Digests `plaintext` with a random salt.

  Returns an Argon2id PHC string (includes salt and parameters).
  """
  @spec digest(binary(), keyword()) :: String.t()
  def digest(plaintext, opts \\ []) when is_binary(plaintext) do
    reject_oversized!(plaintext)
    Argon2.hash_pwd_salt(plaintext, opts)
  end

  @doc """
  Returns `true` when `plaintext` matches `stored` digest.

  Uses a constant-time comparison via Argon2.
  """
  @spec verify(binary(), String.t()) :: boolean()
  def verify(plaintext, stored) when is_binary(plaintext) and is_binary(stored) do
    reject_oversized!(plaintext)
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

  defp reject_oversized!(plaintext) do
    if byte_size(plaintext) > @max_plaintext_bytes do
      raise ArgumentError,
            "plaintext exceeds #{@max_plaintext_bytes} bytes (got #{byte_size(plaintext)})"
    end

    :ok
  end
end
