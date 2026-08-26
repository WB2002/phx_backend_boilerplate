defmodule PhxBackendBoilerplate.Crypto.KMSTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Crypto
  alias PhxBackendBoilerplate.Crypto.KMS

  @context %{"purpose" => "unit-test", "tenant" => "acme"}

  test "encrypt/decrypt round-trip" do
    plaintext = "small-secret-#{System.unique_integer([:positive])}"

    assert {:ok, ciphertext} = KMS.encrypt(plaintext, context: @context)
    assert is_binary(ciphertext)
    assert ciphertext != plaintext

    assert {:ok, ^plaintext} = KMS.decrypt(ciphertext, context: @context)
  end

  test "context mismatch fails decrypt" do
    assert {:ok, ciphertext} = KMS.encrypt("payload", context: @context)

    assert {:error, {:kms_error, :invalid_ciphertext, _}} =
             KMS.decrypt(ciphertext, context: %{"purpose" => "other"})
  end

  test "rejects plaintext larger than 4 KiB" do
    oversized = :binary.copy(<<"x">>, 4097)
    assert {:error, :too_large} = KMS.encrypt(oversized)
  end

  test "returns key_id_missing when unset" do
    previous = Application.get_env(:phx_backend_boilerplate, Crypto)

    Application.put_env(:phx_backend_boilerplate, Crypto,
      key_id: nil,
      kms: PhxBackendBoilerplate.Crypto.KMS.Memory,
      wrapping_key: :binary.copy(<<1>>, 32)
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Crypto, previous)
    end)

    assert {:error, :key_id_missing} = KMS.encrypt("x")
  end

  test "accepts exactly 4096 bytes" do
    plaintext = :binary.copy(<<"y">>, 4096)
    assert {:ok, ciphertext} = KMS.encrypt(plaintext)
    assert {:ok, ^plaintext} = KMS.decrypt(ciphertext)
  end
end
