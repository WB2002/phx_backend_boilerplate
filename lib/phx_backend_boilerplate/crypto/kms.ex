defmodule PhxBackendBoilerplate.Crypto.KMS do
  @moduledoc """
  Direct AWS KMS Encrypt / Decrypt for small binaries (≤ 4096 bytes).

  Prefer `PhxBackendBoilerplate.Crypto.Envelope` for larger payloads.
  """

  alias PhxBackendBoilerplate.Crypto.Config

  @max_plaintext_bytes 4096

  @type opts :: [key_id: String.t(), context: %{optional(String.t()) => String.t()}]

  @doc """
  Encrypts `plaintext` with KMS.

  Options: `:key_id`, `:context` (encryption context map).
  """
  @spec encrypt(binary(), opts()) :: {:ok, binary()} | {:error, term()}
  def encrypt(plaintext, opts \\ []) when is_binary(plaintext) do
    with :ok <- check_size(plaintext),
         {:ok, key_id} <- Config.key_id(opts),
         {:ok, client} <- Config.kms_client() do
      context = Config.context(opts)
      module = client.__struct__

      case module.encrypt(client, key_id, plaintext, context, []) do
        {:ok, %{ciphertext: ciphertext}} -> {:ok, ciphertext}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Decrypts KMS ciphertext.

  Options: `:key_id`, `:context` (must match encrypt-time context).
  """
  @spec decrypt(binary(), opts()) :: {:ok, binary()} | {:error, term()}
  def decrypt(ciphertext, opts \\ []) when is_binary(ciphertext) do
    with {:ok, key_id} <- Config.key_id(opts),
         {:ok, client} <- Config.kms_client() do
      context = Config.context(opts)
      module = client.__struct__

      case module.decrypt(client, key_id, ciphertext, context, []) do
        {:ok, %{plaintext: plaintext}} -> {:ok, plaintext}
        {:error, _} = error -> error
      end
    end
  end

  defp check_size(plaintext) when byte_size(plaintext) > @max_plaintext_bytes do
    {:error, :too_large}
  end

  defp check_size(_plaintext), do: :ok
end
