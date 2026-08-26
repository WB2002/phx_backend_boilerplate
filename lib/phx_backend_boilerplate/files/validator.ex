defmodule PhxBackendBoilerplate.Files.Validator do
  @moduledoc """
  Cheap-to-expensive upload validation: count, size, extension, declared MIME, magic bytes.

  Reads at most ~32 bytes from disk for magic detection — never the whole file.
  """

  alias Plug.Upload

  @magic_read_bytes 32

  @doc """
  Validates a list of `%Plug.Upload{}` structs against Files config.

  Returns `:ok` or `{:error, reason}` where reason is a tagged atom or
  `{atom, detail}` for FallbackController mapping.
  """
  @spec validate_uploads([Upload.t()]) :: :ok | {:error, term()}
  def validate_uploads(uploads) when is_list(uploads) do
    max_files = config(:max_files_per_request, 5)

    cond do
      uploads == [] ->
        {:error, {:too_few_files, "at least one file is required"}}

      length(uploads) > max_files ->
        {:error, {:too_many_files, "at most #{max_files} files allowed"}}

      true ->
        Enum.reduce_while(uploads, :ok, fn upload, :ok ->
          case validate_one(upload) do
            :ok -> {:cont, :ok}
            {:error, _} = err -> {:halt, err}
          end
        end)
    end
  end

  @doc """
  Validates a single `%Plug.Upload{}`.
  """
  @spec validate_one(Upload.t()) :: :ok | {:error, term()}
  def validate_one(%Upload{} = upload) do
    with :ok <- validate_size(upload),
         :ok <- validate_extension(upload),
         :ok <- validate_declared_mime(upload),
         :ok <- validate_magic(upload) do
      :ok
    end
  end

  defp validate_size(%Upload{path: path, filename: filename}) do
    max = config(:max_file_bytes, 100_000_000)

    case File.stat(path) do
      {:ok, %{size: size}} when size > max ->
        {:error, {:file_too_large, "#{filename} exceeds #{max} bytes"}}

      {:ok, %{size: 0}} ->
        {:error, {:empty_file, "#{filename} is empty"}}

      {:ok, _} ->
        :ok

      {:error, reason} ->
        {:error, {:stat_failed, reason}}
    end
  end

  defp validate_extension(%Upload{filename: filename}) do
    allowed = config(:allowed_extensions, [])
    ext = filename |> Path.extname() |> String.downcase()

    if ext in allowed do
      :ok
    else
      {:error, {:invalid_extension, "#{filename} has disallowed extension #{ext}"}}
    end
  end

  defp validate_declared_mime(%Upload{filename: filename, content_type: content_type}) do
    allowed = config(:allowed_content_types, [])
    declared = normalize_mime(content_type)
    from_path = filename |> MIME.from_path() |> normalize_mime()

    cond do
      declared not in allowed ->
        {:error, {:invalid_content_type, "#{filename} declared type #{declared} is not allowed"}}

      not mime_compatible?(declared, from_path) ->
        {:error,
         {:mime_mismatch, "#{filename} declared #{declared} but extension implies #{from_path}"}}

      true ->
        :ok
    end
  end

  defp validate_magic(%Upload{path: path, filename: filename, content_type: content_type}) do
    declared = normalize_mime(content_type)

    if text_type?(declared) do
      :ok
    else
      case read_prefix(path, @magic_read_bytes) do
        {:ok, prefix} ->
          case magic_mime(prefix) do
            nil ->
              {:error, {:invalid_magic, "#{filename} contents do not match a known type"}}

            detected ->
              if detected == declared or compatible_magic?(declared, detected) do
                :ok
              else
                {:error,
                 {:magic_mismatch,
                  "#{filename} declared #{declared} but contents look like #{detected}"}}
              end
          end

        {:error, reason} ->
          {:error, {:read_failed, reason}}
      end
    end
  end

  defp read_prefix(path, n) do
    with {:ok, file} <- File.open(path, [:read, :raw, :binary]),
         {:ok, data} <- :file.pread(file, 0, n) do
      File.close(file)
      {:ok, data}
    else
      :eof ->
        {:error, :eof}

      {:error, _} = err ->
        err

      other ->
        {:error, other}
    end
  end

  # Magic signatures — order matters for overlapping prefixes.
  defp magic_mime(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>), do: "image/png"
  defp magic_mime(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"
  defp magic_mime(<<"GIF87a", _::binary>>), do: "image/gif"
  defp magic_mime(<<"GIF89a", _::binary>>), do: "image/gif"
  defp magic_mime(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>), do: "image/webp"
  defp magic_mime(<<"%PDF", _::binary>>), do: "application/pdf"
  defp magic_mime(<<0x50, 0x4B, 0x03, 0x04, _::binary>>), do: "application/zip"
  defp magic_mime(<<0x50, 0x4B, 0x05, 0x06, _::binary>>), do: "application/zip"
  defp magic_mime(<<0x50, 0x4B, 0x07, 0x08, _::binary>>), do: "application/zip"
  defp magic_mime(_), do: nil

  defp text_type?(mime), do: String.starts_with?(mime, "text/")

  defp compatible_magic?("application/x-zip-compressed", "application/zip"), do: true
  defp compatible_magic?(_, _), do: false

  defp mime_compatible?(declared, from_path) do
    declared == from_path or
      (declared in ~w(application/zip application/x-zip-compressed) and
         from_path in ~w(application/zip application/x-zip-compressed)) or
      (declared == "image/jpeg" and from_path == "image/jpeg")
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

  defp config(key, default) do
    Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
    |> Keyword.get(key, default)
  end
end
