defmodule PhxBackendBoilerplate.Crypto.EnvelopeTest do
  use ExUnit.Case, async: false

  alias PhxBackendBoilerplate.Crypto
  alias PhxBackendBoilerplate.Crypto.Envelope

  @context %{"purpose" => "envelope-test"}

  test "seal/open round-trip for small payload" do
    plaintext = "envelope-#{System.unique_integer([:positive])}"

    assert {:ok, message} = Envelope.seal(plaintext, context: @context)
    assert is_binary(message)
    assert message != plaintext

    assert {:ok, ^plaintext} = Envelope.open(message)
  end

  test "seal/open round-trip for payload larger than 4 KiB" do
    plaintext = :binary.copy(<<"z">>, 5_000)

    assert {:ok, message} = Envelope.seal(plaintext, context: @context)
    assert {:ok, ^plaintext} = Envelope.open(message)
  end

  test "open with_context returns encryption context" do
    assert {:ok, message} = Envelope.seal("data", context: @context)
    assert {:ok, {"data", context}} = Envelope.open(message, with_context: true)
    assert context["purpose"] == "envelope-test"
  end

  test "wrong wrapping key fails open" do
    assert {:ok, message} = Envelope.seal("secret", context: @context)

    previous = Application.get_env(:phx_backend_boilerplate, Crypto)

    Application.put_env(
      :phx_backend_boilerplate,
      Crypto,
      Keyword.merge(previous, wrapping_key: :binary.copy(<<9>>, 32))
    )

    on_exit(fn ->
      Application.put_env(:phx_backend_boilerplate, Crypto, previous)
    end)

    assert {:error, _} = Envelope.open(message)
  end

  test "reproduced context mismatch fails open" do
    assert {:ok, message} = Envelope.seal("secret", context: @context)

    assert {:error, _} =
             Envelope.open(message, context: %{"purpose" => "different"})
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

    assert {:error, :key_id_missing} = Envelope.seal("x")
  end
end
