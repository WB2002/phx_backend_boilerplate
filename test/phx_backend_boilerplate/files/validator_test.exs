defmodule PhxBackendBoilerplate.Files.ValidatorTest do
  use ExUnit.Case, async: true

  alias PhxBackendBoilerplate.Files.Validator
  alias Plug.Upload

  setup do
    dir = Path.join(System.tmp_dir!(), "validator-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "accepts a valid PNG", %{dir: dir} do
    path = write_png(dir, "ok.png")
    upload = upload(path, "ok.png", "image/png")
    assert :ok = Validator.validate_one(upload)
  end

  test "rejects disallowed extension", %{dir: dir} do
    path = Path.join(dir, "x.exe")
    File.write!(path, "MZ")
    upload = upload(path, "x.exe", "application/octet-stream")
    assert {:error, {:invalid_extension, _}} = Validator.validate_one(upload)
  end

  test "rejects magic mismatch", %{dir: dir} do
    path = Path.join(dir, "fake.png")
    File.write!(path, "not a png")
    upload = upload(path, "fake.png", "image/png")
    assert {:error, {:invalid_magic, _}} = Validator.validate_one(upload)
  end

  test "rejects oversized files", %{dir: dir} do
    # test max_file_bytes is 1_000_000
    path = Path.join(dir, "big.png")
    File.write!(path, png_bytes() <> :crypto.strong_rand_bytes(1_000_001))
    upload = upload(path, "big.png", "image/png")
    assert {:error, {:file_too_large, _}} = Validator.validate_one(upload)
  end

  test "rejects too many files", %{dir: dir} do
    uploads =
      for i <- 1..6 do
        path = write_png(dir, "f#{i}.png")
        upload(path, "f#{i}.png", "image/png")
      end

    assert {:error, {:too_many_files, _}} = Validator.validate_uploads(uploads)
  end

  test "allows text without magic", %{dir: dir} do
    path = Path.join(dir, "notes.txt")
    File.write!(path, "hello world")
    upload = upload(path, "notes.txt", "text/plain")
    assert :ok = Validator.validate_one(upload)
  end

  defp upload(path, filename, content_type) do
    %Upload{path: path, filename: filename, content_type: content_type}
  end

  defp write_png(dir, name) do
    path = Path.join(dir, name)
    File.write!(path, png_bytes())
    path
  end

  defp png_bytes do
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, "IHDR", 0, 0, 0, 1, 0, 0, 0, 1>>
  end
end
