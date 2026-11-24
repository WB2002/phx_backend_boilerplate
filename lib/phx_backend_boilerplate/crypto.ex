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

  alias PhxBackendBoilerplate.Crypto.{Config, Digest, Envelope, KMS}

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
  defdelegate config(key, default \\ nil), to: Config

  @doc false
  defdelegate key_id(opts), to: Config

  @doc false
  defdelegate context(opts), to: Config

  @doc false
  defdelegate kms_client(), to: Config
end
