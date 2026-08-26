defmodule PhxBackendBoilerplate.Crypto.DigestTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Crypto.Digest

  test "digest returns an argon2id PHC string" do
    stored = Digest.digest("secret-value")
    assert String.starts_with?(stored, "$argon2id$")
  end

  test "verify succeeds for matching plaintext" do
    stored = Digest.digest("correct-horse")
    assert Digest.verify("correct-horse", stored)
  end

  test "verify fails for mismatched plaintext" do
    stored = Digest.digest("correct-horse")
    refute Digest.verify("wrong-battery", stored)
  end

  test "dummy_verify always returns false" do
    refute Digest.dummy_verify()
  end
end
