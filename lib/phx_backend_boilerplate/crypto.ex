defmodule PhxBackendBoilerplate.Crypto do
  @moduledoc """
  Generic cryptographic helpers for digests (Argon2id), direct AWS KMS
  encrypt/decrypt (≤ 4 KiB), and envelope seal/open (AWS Encryption SDK).

  Configure via `config :phx_backend_boilerplate, PhxBackendBoilerplate.Crypto`:

  * `:key_id` — KMS key id / ARN / alias (from `KMS_KEY_ID` in runtime)
  * `:kms` — client module (`Crypto.KMS.ExAws` or `Crypto.KMS.Memory`)
  * `:wrapping_key` — 32-byte key for Memory adapter (tests only)

  Public names stay domain-agnostic (`digest` / `verify` / `encrypt` /
  `decrypt` / `seal` / `open`).
  """

  alias PhxBackendBoilerplate.Crypto.{Digest, Envelope, KMS}

  defdelegate digest(plaintext), to: Digest
  defdelegate digest(plaintext, opts), to: Digest
  defdelegate verify(plaintext, stored), to: Digest
  defdelegate dummy_verify(), to: Digest

  defdelegate encrypt(plaintext), to: KMS
  defdelegate encrypt(plaintext, opts), to: KMS
  defdelegate decrypt(ciphertext), to: KMS
  defdelegate decrypt(ciphertext, opts), to: KMS

  defdelegate seal(plaintext), to: Envelope
  defdelegate seal(plaintext, opts), to: Envelope
  defdelegate open(message), to: Envelope
  defdelegate open(message, opts), to: Envelope

  @doc false
  def config(key, default \\ nil) do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(key, default)
  end

  @doc false
  def key_id(opts) when is_list(opts) do
    case Keyword.get(opts, :key_id) || config(:key_id) do
      id when is_binary(id) and id != "" -> {:ok, id}
      _ -> {:error, :key_id_missing}
    end
  end

  @doc false
  def context(opts) when is_list(opts) do
    case Keyword.get(opts, :context, %{}) do
      ctx when is_map(ctx) -> ctx
      _ -> %{}
    end
  end

  @doc false
  def kms_client do
    module = config(:kms, PhxBackendBoilerplate.Crypto.KMS.ExAws)
    module.new()
  end
end
