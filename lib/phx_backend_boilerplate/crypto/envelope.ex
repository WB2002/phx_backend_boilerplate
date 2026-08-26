defmodule PhxBackendBoilerplate.Crypto.Envelope do
  @moduledoc """
  Envelope encryption via the AWS Encryption SDK (KMS keyring).

  Produces message-format ciphertext compatible with other AWS Encryption SDK
  implementations. Suitable for payloads of any size (unlike direct KMS).
  """

  alias AwsEncryptionSdk.Client
  alias AwsEncryptionSdk.Cmm.Default
  alias AwsEncryptionSdk.Keyring.AwsKms
  alias PhxBackendBoilerplate.Crypto

  @type opts :: [
          key_id: String.t(),
          context: %{optional(String.t()) => String.t()},
          with_context: boolean()
        ]

  @doc """
  Seals `plaintext` into an Encryption SDK message.

  Options: `:key_id`, `:context`.
  """
  @spec seal(binary(), opts()) :: {:ok, binary()} | {:error, term()}
  def seal(plaintext, opts \\ []) when is_binary(plaintext) do
    with {:ok, client} <- sdk_client(opts) do
      context = Crypto.context(opts)

      case Client.encrypt(client, plaintext, encryption_context: context) do
        {:ok, %{ciphertext: ciphertext}} -> {:ok, ciphertext}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Opens an Encryption SDK message.

  By default returns `{:ok, plaintext}`. Pass `with_context: true` to get
  `{:ok, {plaintext, encryption_context}}`.

  Options: `:key_id`, `:context` (reproduced context validation), `:with_context`.
  """
  @spec open(binary(), opts()) ::
          {:ok, binary()} | {:ok, {binary(), map()}} | {:error, term()}
  def open(message, opts \\ []) when is_binary(message) do
    with {:ok, client} <- sdk_client(opts) do
      decrypt_opts =
        case Keyword.fetch(opts, :context) do
          {:ok, ctx} when is_map(ctx) -> [encryption_context: ctx]
          _ -> []
        end

      case Client.decrypt(client, message, decrypt_opts) do
        {:ok, %{plaintext: plaintext, encryption_context: encryption_context}} ->
          if Keyword.get(opts, :with_context, false) do
            {:ok, {plaintext, encryption_context}}
          else
            {:ok, plaintext}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  defp sdk_client(opts) do
    with {:ok, key_id} <- Crypto.key_id(opts),
         {:ok, kms_client} <- Crypto.kms_client(),
         {:ok, keyring} <- AwsKms.new(key_id, kms_client) do
      {:ok, Client.new(Default.new(keyring))}
    end
  end
end
