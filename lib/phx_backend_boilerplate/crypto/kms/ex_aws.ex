defmodule PhxBackendBoilerplate.Crypto.KMS.ExAws do
  @moduledoc """
  Production KMS client factory.

  Returns an `AwsEncryptionSdk.Keyring.KmsClient.ExAws` struct so both
  `Crypto.KMS` (direct Encrypt/Decrypt) and `Crypto.Envelope` (keyring)
  share the same ExAws + Req HTTP path configured for this app.
  """

  @doc "Builds an ExAws-backed KMS client for the configured region."
  @spec new(keyword()) :: {:ok, AwsEncryptionSdk.Keyring.KmsClient.ExAws.t()}
  def new(opts \\ []) do
    region = Keyword.get(opts, :region) || Application.get_env(:ex_aws, :region)
    AwsEncryptionSdk.Keyring.KmsClient.ExAws.new(region: region)
  end
end
