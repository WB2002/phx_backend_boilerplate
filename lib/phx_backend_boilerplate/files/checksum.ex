defmodule PhxBackendBoilerplate.Files.Checksum do
  @moduledoc """
  Incremental SHA-256 over a file path in fixed-size chunks.

  Never loads the whole file into memory — suitable for multi-GB uploads.
  """

  @default_chunk 10_485_760

  @doc """
  Returns lowercase hex SHA-256 of the file at `path`.

  Chunks with `hash_chunk_bytes` from `PhxBackendBoilerplate.Files` config
  (default 10 MiB).
  """
  @spec sha256_file(Path.t()) :: {:ok, String.t()} | {:error, term()}
  def sha256_file(path) when is_binary(path) do
    chunk = config(:hash_chunk_bytes, @default_chunk)

    try do
      digest =
        path
        |> File.stream!(chunk, [])
        |> Enum.reduce(:crypto.hash_init(:sha256), fn bytes_chunk, acc ->
          :crypto.hash_update(acc, bytes_chunk)
        end)
        |> :crypto.hash_final()
        |> Base.encode16(case: :lower)

      {:ok, digest}
    rescue
      e in [File.Error, ErlangError] -> {:error, e}
    end
  end

  @doc """
  Constant-time compare of two hex digests (case-insensitive).
  """
  @spec matches?(String.t(), String.t()) :: boolean()
  def matches?(expected, actual)
      when is_binary(expected) and is_binary(actual) do
    Plug.Crypto.secure_compare(String.downcase(expected), String.downcase(actual))
  end

  defp config(key, default) do
    Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
    |> Keyword.get(key, default)
  end
end
