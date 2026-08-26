defmodule PhxBackendBoilerplate.Files.ChecksumTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Files.Checksum

  setup do
    path = Path.join(System.tmp_dir!(), "checksum-#{System.unique_integer([:positive])}.bin")
    # Larger than test hash_chunk_bytes (1024) so we exercise multi-chunk hashing.
    data = :crypto.strong_rand_bytes(3500)
    File.write!(path, data)
    on_exit(fn -> File.rm(path) end)
    %{path: path, data: data}
  end

  test "hashes incrementally without loading whole file semantics", %{path: path, data: data} do
    expected =
      :crypto.hash(:sha256, data)
      |> Base.encode16(case: :lower)

    assert {:ok, ^expected} = Checksum.sha256_file(path)
  end

  test "matches?/2 is case-insensitive", %{path: path} do
    {:ok, digest} = Checksum.sha256_file(path)
    assert Checksum.matches?(digest, digest)
    assert Checksum.matches?(String.upcase(digest), digest)
    refute Checksum.matches?(digest, String.duplicate("0", 64))
  end
end
