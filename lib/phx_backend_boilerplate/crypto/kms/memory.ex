defmodule PhxBackendBoilerplate.Crypto.KMS.Memory do
  @moduledoc """
  In-process KMS stand-in for tests.

  Implements `AwsEncryptionSdk.Keyring.KmsClient` with AES-256-GCM wrapping
  under a configured 32-byte `:wrapping_key`. Encryption context is bound as
  AAD so context mismatches fail authentication.

  Envelope round-trips require a real KMS ARN as `key_id` (Encryption SDK
  validates response key ids).
  """

  @behaviour AwsEncryptionSdk.Keyring.KmsClient

  alias AwsEncryptionSdk.Keyring.KmsClient

  defstruct [:wrapping_key]

  @type t :: %__MODULE__{wrapping_key: binary()}

  @iv_bytes 12
  @tag_bytes 16

  @doc """
  Builds a Memory client.

  Options:

  * `:wrapping_key` — 32-byte binary (defaults to Crypto config)
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, :wrapping_key_invalid}
  def new(opts \\ []) do
    key =
      Keyword.get(opts, :wrapping_key) ||
        PhxBackendBoilerplate.Crypto.Config.config(:wrapping_key)

    if is_binary(key) and byte_size(key) == 32 do
      {:ok, %__MODULE__{wrapping_key: key}}
    else
      {:error, :wrapping_key_invalid}
    end
  end

  @impl KmsClient
  def generate_data_key(
        %__MODULE__{} = client,
        key_id,
        number_of_bytes,
        encryption_context,
        _grants
      )
      when is_binary(key_id) and is_integer(number_of_bytes) and number_of_bytes > 0 do
    plaintext = :crypto.strong_rand_bytes(number_of_bytes)

    case wrap(client, plaintext, encryption_context) do
      {:ok, ciphertext} ->
        {:ok, %{plaintext: plaintext, ciphertext: ciphertext, key_id: key_id}}

      {:error, _} = error ->
        error
    end
  end

  @impl KmsClient
  def encrypt(%__MODULE__{} = client, key_id, plaintext, encryption_context, _grants)
      when is_binary(key_id) and is_binary(plaintext) do
    case wrap(client, plaintext, encryption_context) do
      {:ok, ciphertext} ->
        {:ok, %{ciphertext: ciphertext, key_id: key_id}}

      {:error, _} = error ->
        error
    end
  end

  @impl KmsClient
  def decrypt(%__MODULE__{} = client, key_id, ciphertext, encryption_context, _grants)
      when is_binary(key_id) and is_binary(ciphertext) do
    case unwrap(client, ciphertext, encryption_context) do
      {:ok, plaintext} ->
        {:ok, %{plaintext: plaintext, key_id: key_id}}

      {:error, _} = error ->
        error
    end
  end

  defp wrap(%__MODULE__{wrapping_key: key}, plaintext, encryption_context) do
    iv = :crypto.strong_rand_bytes(@iv_bytes)
    aad = aad(encryption_context)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, aad, true)

    {:ok, iv <> tag <> ciphertext}
  rescue
    error ->
      {:error, {:kms_error, :encrypt_failed, Exception.message(error)}}
  end

  defp unwrap(%__MODULE__{wrapping_key: key}, blob, encryption_context)
       when byte_size(blob) > @iv_bytes + @tag_bytes do
    <<iv::binary-size(@iv_bytes), tag::binary-size(@tag_bytes), ciphertext::binary>> = blob
    aad = aad(encryption_context)

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, aad, tag, false) do
      plaintext when is_binary(plaintext) ->
        {:ok, plaintext}

      :error ->
        {:error, {:kms_error, :invalid_ciphertext, "authentication failed"}}
    end
  end

  defp unwrap(_client, _blob, _encryption_context) do
    {:error, {:kms_error, :invalid_ciphertext, "ciphertext too short"}}
  end

  defp aad(context) when is_map(context) and map_size(context) == 0, do: <<>>

  defp aad(context) when is_map(context) do
    context
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map_join("&", fn {k, v} -> "#{k}=#{v}" end)
  end
end
