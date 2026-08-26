defmodule PhxBackendBoilerplateWeb.Demo.FilesController do
  @moduledoc """
  Demo multi-file upload + resumable Range download.

  Upload: `POST /api/demo/files` multipart field `files` (list) and optional
  `sha256` list aligned by index. Download: `GET`/`HEAD` with `Range` → 206.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.Files
  alias PhxBackendBoilerplate.Files.StoredFile
  alias Plug.Conn
  alias Plug.Upload

  action_fallback PhxBackendBoilerplateWeb.FallbackController

  def create(conn, params) do
    uploads = normalize_uploads(params)
    sha256s = normalize_sha256s(params)

    case Files.ingest(uploads, sha256s) do
      {:ok, stored} ->
        conn
        |> put_status(:created)
        |> json(%{data: Enum.map(stored, &file_json/1)})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, file} <- Files.get(id) do
      serve(conn, file)
    end
  end

  def head(conn, %{"id" => id}) do
    with {:ok, file} <- Files.get(id) do
      conn
      |> put_file_headers(file)
      |> send_resp(200, "")
    end
  end

  defp serve(conn, %StoredFile{} = file) do
    case parse_range(get_req_header(conn, "range"), file.byte_size) do
      :full ->
        send_full(conn, file)

      {:partial, start_pos, end_pos} ->
        length = end_pos - start_pos + 1

        conn
        |> put_file_headers(file)
        |> put_resp_header(
          "content-range",
          "bytes #{start_pos}-#{end_pos}/#{file.byte_size}"
        )
        |> put_resp_header("content-length", Integer.to_string(length))
        |> send_partial(file, start_pos, length)

      :unsatisfiable ->
        conn
        |> put_resp_header("content-range", "bytes */#{file.byte_size}")
        |> put_resp_content_type("application/json")
        |> send_resp(416, Jason.encode!(%{errors: %{detail: "Range Not Satisfiable"}}))
    end
  end

  defp send_full(conn, %StoredFile{} = file) do
    conn = put_file_headers(conn, file)

    case Files.local_path(file) do
      path when is_binary(path) ->
        Conn.send_file(conn, 200, path)

      nil ->
        with {:ok, _file, stream} <- Files.open_stream(file.id, 0, :eof) do
          conn = send_chunked(conn, 200)

          Enum.reduce_while(stream, conn, fn chunk, acc ->
            case chunk(acc, chunk) do
              {:ok, acc} -> {:cont, acc}
              {:error, :closed} -> {:halt, acc}
            end
          end)
        end
    end
  end

  defp send_partial(conn, %StoredFile{} = file, start_pos, length) do
    case Files.local_path(file) do
      path when is_binary(path) ->
        # Plug.Conn.send_file/5 (offset, length)
        Conn.send_file(conn, 206, path, start_pos, length)

      nil ->
        with {:ok, _file, stream} <- Files.open_stream(file.id, start_pos, length) do
          conn = send_chunked(conn, 206)

          Enum.reduce_while(stream, conn, fn chunk, acc ->
            case chunk(acc, chunk) do
              {:ok, acc} -> {:cont, acc}
              {:error, :closed} -> {:halt, acc}
            end
          end)
        end
    end
  end

  defp put_file_headers(conn, %StoredFile{} = file) do
    conn
    |> put_resp_content_type(file.content_type)
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("content-length", Integer.to_string(file.byte_size))
    |> put_resp_header(
      "content-disposition",
      ~s(attachment; filename="#{escape_filename(file.filename)}")
    )
    |> put_resp_header("etag", ~s("#{file.sha256}"))
  end

  defp parse_range([], _size), do: :full

  defp parse_range([header | _], size) do
    case Regex.run(~r/^bytes=(\d*)-(\d*)$/, String.trim(header)) do
      [_, "", ""] ->
        :unsatisfiable

      [_, start_s, end_s] ->
        start_pos = if start_s == "", do: nil, else: String.to_integer(start_s)
        end_pos = if end_s == "", do: nil, else: String.to_integer(end_s)

        cond do
          # bytes=-N → last N bytes
          is_nil(start_pos) and is_integer(end_pos) and end_pos > 0 ->
            len = min(end_pos, size)
            {:partial, size - len, size - 1}

          is_integer(start_pos) and start_pos >= size ->
            :unsatisfiable

          is_integer(start_pos) and is_nil(end_pos) ->
            {:partial, start_pos, size - 1}

          is_integer(start_pos) and is_integer(end_pos) and end_pos >= start_pos ->
            {:partial, start_pos, min(end_pos, size - 1)}

          true ->
            :unsatisfiable
        end

      _ ->
        :full
    end
  end

  defp normalize_uploads(params) do
    params
    |> Map.get("files")
    |> Kernel.||(Map.get(params, "files[]"))
    |> Kernel.||(Map.get(params, "file"))
    |> List.wrap()
    |> Enum.filter(&match?(%Upload{}, &1))
  end

  defp normalize_sha256s(params) do
    case Map.get(params, "sha256") || Map.get(params, "sha256[]") do
      nil -> nil
      list when is_list(list) -> list
      one when is_binary(one) -> [one]
    end
  end

  defp file_json(%StoredFile{} = f) do
    %{
      id: f.id,
      filename: f.filename,
      content_type: f.content_type,
      byte_size: f.byte_size,
      sha256: f.sha256
    }
  end

  defp escape_filename(name) do
    String.replace(name, ~r/["\\\r\n]/, "_")
  end
end
