defmodule PhxBackendBoilerplate.Crypto.LocalstackTest do
  use ExUnit.Case, async: false

  @moduletag :localstack

  alias PhxBackendBoilerplate.Crypto
  alias PhxBackendBoilerplate.Crypto.{Envelope, KMS}

  setup_all do
    unless System.get_env("AWS_ENDPOINT_URL") do
      flunk("AWS_ENDPOINT_URL must be set for :localstack tests (e.g. http://localhost:4566)")
    end

    key_id =
      case System.get_env("KMS_KEY_ID") do
        id when is_binary(id) and id != "" ->
          id

        _ ->
          case ExAws.KMS.create_key([]) |> ExAws.request() do
            {:ok, %{"KeyMetadata" => %{"Arn" => arn}}} ->
              arn

            {:ok, %{"KeyMetadata" => %{"KeyId" => id}}} ->
              id

            other ->
              flunk("failed to create LocalStack KMS key: #{inspect(other)}")
          end
      end

    previous = Application.get_env(:phx_backend_boilerplate, Crypto)

    Application.put_env(
      :phx_backend_boilerplate,
      Crypto,
      Keyword.merge(previous || [],
        key_id: key_id,
        kms: PhxBackendBoilerplate.Crypto.KMS.ExAws
      )
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:phx_backend_boilerplate, Crypto, previous)
      end
    end)

    %{key_id: key_id}
  end

  test "direct KMS encrypt/decrypt against LocalStack", %{key_id: key_id} do
    plaintext = "localstack-kms-#{System.unique_integer([:positive])}"
    context = %{"purpose" => "localstack"}

    assert {:ok, ciphertext} = KMS.encrypt(plaintext, key_id: key_id, context: context)
    assert {:ok, ^plaintext} = KMS.decrypt(ciphertext, key_id: key_id, context: context)
  end

  test "envelope seal/open against LocalStack", %{key_id: key_id} do
    plaintext = :binary.copy(<<"L">>, 5_000)
    context = %{"purpose" => "localstack-envelope"}

    assert {:ok, message} = Envelope.seal(plaintext, key_id: key_id, context: context)
    assert {:ok, ^plaintext} = Envelope.open(message, key_id: key_id)
  end
end
