defmodule PhxBackendBoilerplate.Files do
  @moduledoc """
  Upload pipeline: validate → incremental SHA-256 → ClamAV → storage → DB.

  Multi-file ingest is **all-or-nothing**: if any file fails after others were
  stored, previously stored objects and rows from that request are rolled back.
  """

  alias PhxBackendBoilerplate.Files.{Checksum, Scanner, Storage, StoredFile, Validator}
  alias PhxBackendBoilerplate.Repo
  alias Plug.Upload

  @doc """
  Ingest one or more `%Plug.Upload{}` structs.

  `expected_sha256s` is an optional list of hex digests aligned with `uploads`
  (same order). Pass `nil` or omit entries to skip client checksum checks.
  """
  @spec ingest([Upload.t()], [String.t() | nil] | nil) ::
          {:ok, [StoredFile.t()]} | {:error, term()}
  def ingest(uploads, expected_sha256s \\ nil)

  def ingest(uploads, expected_sha256s) when is_list(uploads) do
    expected = List.wrap(expected_sha256s)

    with :ok <- Validator.validate_uploads(uploads) do
      uploads
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, []}, fn {upload, index}, {:ok, acc} ->
        expected_hash = Enum.at(expected, index)

        case ingest_one(upload, expected_hash) do
          {:ok, stored} ->
            {:cont, {:ok, [stored | acc]}}

          {:error, reason} ->
            rollback_stored(acc)
            {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, stored} -> {:ok, Enum.reverse(stored)}
        {:error, _} = err -> err
      end
    end
  end

  @doc "Fetch stored file metadata by id."
  @spec get(Ecto.UUID.t()) :: {:ok, StoredFile.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    case Repo.get(StoredFile, id) do
      nil -> {:error, :not_found}
      file -> {:ok, file}
    end
  end

  @doc "Delete metadata and storage object."
  @spec delete(StoredFile.t() | Ecto.UUID.t()) :: :ok | {:error, term()}
  def delete(%StoredFile{} = file) do
    _ = Storage.delete(file.storage_key)

    case Repo.delete(file) do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  def delete(id) when is_binary(id) do
    with {:ok, file} <- get(id) do
      delete(file)
    end
  end

  @doc """
  Stream bytes for download. Returns `{:ok, stored_file, enumerable}` or error.
  """
  @spec open_stream(Ecto.UUID.t(), non_neg_integer(), non_neg_integer() | :eof) ::
          {:ok, StoredFile.t(), Enumerable.t()} | {:error, term()}
  def open_stream(id, offset \\ 0, length \\ :eof) do
    with {:ok, file} <- get(id),
         {:ok, stream} <- Storage.stream(file.storage_key, offset, length) do
      {:ok, file, stream}
    end
  end

  @doc "Absolute path for `send_file` when using local storage; otherwise nil."
  @spec local_path(StoredFile.t()) :: Path.t() | nil
  def local_path(%StoredFile{storage_key: key}), do: Storage.local_path(key)

  defp ingest_one(%Upload{} = upload, expected_sha256) do
    case Validator.validate_one(upload) do
      :ok ->
        do_ingest_one(upload, expected_sha256)

      {:error, _} = err ->
        err
    end
  end

  defp do_ingest_one(%Upload{} = upload, expected_sha256) do
    with {:ok, %{size: byte_size}} <- File.stat(upload.path),
         {:ok, sha256} <- Checksum.sha256_file(upload.path),
         :ok <- maybe_verify_checksum(expected_sha256, sha256) do
      case Scanner.scan_file(upload.path) do
        :clean ->
          store_and_persist(upload, byte_size, sha256)

        {:error, :infected} ->
          {:error, :infected}

        {:error, :scanner_unavailable} ->
          {:error, :scanner_unavailable}

        {:error, reason} ->
          {:error, {:scanner_error, reason}}
      end
    end
  end

  defp store_and_persist(%Upload{} = upload, byte_size, sha256) do
    storage_key = build_key(upload, sha256)

    case Storage.put(storage_key, upload.path) do
      :ok ->
        attrs = %{
          filename: upload.filename,
          content_type: normalize_mime(upload.content_type),
          byte_size: byte_size,
          sha256: sha256,
          storage_backend: Storage.backend_name(),
          storage_key: storage_key
        }

        case %StoredFile{} |> StoredFile.changeset(attrs) |> Repo.insert() do
          {:ok, stored} ->
            {:ok, stored}

          {:error, changeset} ->
            _ = Storage.delete(storage_key)
            {:error, changeset}
        end

      {:error, reason} ->
        {:error, {:storage_error, reason}}
    end
  end

  defp maybe_verify_checksum(nil, _actual), do: :ok
  defp maybe_verify_checksum("", _actual), do: :ok

  defp maybe_verify_checksum(expected, actual) when is_binary(expected) do
    if Checksum.matches?(expected, actual) do
      :ok
    else
      {:error, :checksum_mismatch}
    end
  end

  defp build_key(%Upload{filename: filename}, sha256) do
    ext = filename |> Path.extname() |> String.downcase()
    date = Date.utc_today() |> Date.to_iso8601()
    id = Ecto.UUID.generate()
    Path.join([date, "#{id}-#{sha256}#{ext}"])
  end

  defp normalize_mime(nil), do: "application/octet-stream"
  defp normalize_mime(""), do: "application/octet-stream"

  defp normalize_mime(mime) when is_binary(mime) do
    mime
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
    |> String.downcase()
  end

  defp rollback_stored(stored_files) do
    Enum.each(stored_files, fn file ->
      _ = Storage.delete(file.storage_key)
      _ = Repo.delete(file)
    end)
  end
end
