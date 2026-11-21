defmodule PhxBackendBoilerplate.Files.Storage.Local do
  @moduledoc """
  Local filesystem storage under `local_root` (default `priv/uploads`).
  """

  @behaviour PhxBackendBoilerplate.Files.Storage

  @default_chunk 10_485_760

  @impl true
  def put(key, path) when is_binary(key) and is_binary(path) do
    dest = absolute(key)
    File.mkdir_p!(Path.dirname(dest))

    case File.cp(path, dest) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key) when is_binary(key) do
    path = absolute(key)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def stream(key, offset, length)
      when is_binary(key) and is_integer(offset) and offset >= 0 do
    path = absolute(key)

    case File.stat(path) do
      {:ok, %{size: size}} when offset >= size ->
        {:error, :out_of_range}

      {:ok, %{size: size}} ->
        to_read = remaining(length, size, offset)
        {:ok, build_stream(path, offset, to_read)}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def local_path(key) when is_binary(key), do: absolute(key)

  defp build_stream(path, offset, total) do
    chunk = chunk_size()

    Stream.resource(
      fn ->
        {:ok, file} = File.open(path, [:read, :raw, :binary])
        {file, offset, total}
      end,
      fn
        {file, _off, 0} ->
          {:halt, file}

        {file, off, rem} ->
          n = min(chunk, rem)

          case :file.pread(file, off, n) do
            {:ok, bytes_read} when is_binary(bytes_read) and byte_size(bytes_read) > 0 ->
              {[bytes_read], {file, off + byte_size(bytes_read), rem - byte_size(bytes_read)}}

            _ ->
              {:halt, file}
          end
      end,
      fn file -> File.close(file) end
    )
  end

  defp remaining(:eof, size, offset), do: max(size - offset, 0)
  defp remaining(n, size, offset) when is_integer(n), do: min(n, max(size - offset, 0))

  defp absolute(key) do
    root =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
      |> Keyword.get(:local_root, "priv/uploads")

    root =
      if Path.type(root) == :absolute do
        root
      else
        Path.expand(root)
      end

    safe = key |> Path.split() |> Enum.reject(&(&1 in [".", "..", ""])) |> Path.join()
    Path.join(root, safe)
  end

  defp chunk_size do
    Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
    |> Keyword.get(:hash_chunk_bytes, @default_chunk)
  end
end
