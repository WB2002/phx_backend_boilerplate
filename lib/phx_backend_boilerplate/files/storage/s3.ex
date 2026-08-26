defmodule PhxBackendBoilerplate.Files.Storage.S3 do
  @moduledoc """
  S3 object storage via ExAws. Streams uploads and ranged downloads in chunks.
  """

  @behaviour PhxBackendBoilerplate.Files.Storage

  @default_chunk 10_485_760

  @impl true
  def put(key, path) when is_binary(key) and is_binary(path) do
    bucket = bucket!()

    path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(bucket, key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key) when is_binary(key) do
    bucket = bucket!()

    bucket
    |> ExAws.S3.delete_object(key)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def stream(key, offset, length)
      when is_binary(key) and is_integer(offset) and offset >= 0 do
    rem =
      case length do
        :eof -> :infinity
        n when is_integer(n) and n >= 0 -> n
      end

    stream =
      Stream.resource(
        fn -> {offset, rem} end,
        fn
          {_off, 0} ->
            {:halt, :done}

          {off, rem} ->
            n =
              case rem do
                :infinity -> chunk_size()
                left -> min(chunk_size(), left)
              end

            case get_range(key, off, n) do
              {:ok, data} when byte_size(data) == 0 ->
                {:halt, :done}

              {:ok, data} ->
                next_rem =
                  case rem do
                    :infinity -> :infinity
                    left -> left - byte_size(data)
                  end

                {[data], {off + byte_size(data), next_rem}}

              {:error, :not_found} ->
                {:halt, :not_found}

              {:error, _} ->
                {:halt, :done}
            end

          :done ->
            {:halt, :done}

          :not_found ->
            {:halt, :not_found}
        end,
        fn _ -> :ok end
      )

    # Probe first byte so missing keys fail fast with {:error, :not_found}
    case get_range(key, offset, 1) do
      {:ok, _} -> {:ok, stream}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def local_path(_key), do: nil

  defp get_range(key, offset, n) when n > 0 do
    bucket = bucket!()
    range = "bytes=#{offset}-#{offset + n - 1}"

    bucket
    |> ExAws.S3.get_object(key, range: range)
    |> ExAws.request()
    |> case do
      {:ok, %{body: body}} when is_binary(body) -> {:ok, body}
      {:error, {:http_error, 404, _}} -> {:error, :not_found}
      {:error, {:http_error, 416, _}} -> {:ok, ""}
      {:error, reason} -> {:error, reason}
    end
  end

  defp chunk_size do
    Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
    |> Keyword.get(:hash_chunk_bytes, @default_chunk)
  end

  defp bucket! do
    bucket =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
      |> Keyword.get(:s3_bucket)

    bucket || raise ArgumentError, "S3_BUCKET / :s3_bucket is required for S3 storage"
  end
end
