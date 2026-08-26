defmodule PhxBackendBoilerplate.Files.Scanner.ClamAV do
  @moduledoc """
  ClamAV `clamd` client using the INSTREAM protocol over TCP.

  Streams the file in chunked frames so multi-GB files never sit in RAM.
  Unavailable daemon → `{:error, :scanner_unavailable}` (fail-closed).
  """

  @behaviour PhxBackendBoilerplate.Files.Scanner

  @default_chunk 10_485_760
  @connect_timeout 5_000
  @recv_timeout 120_000

  @impl true
  def scan_file(path) when is_binary(path) do
    {host, port} = clamav_endpoint()
    chunk = hash_chunk()

    case :gen_tcp.connect(
           String.to_charlist(host),
           port,
           [:binary, active: false, packet: :raw],
           @connect_timeout
         ) do
      {:ok, socket} ->
        try do
          do_instream(socket, path, chunk)
        after
          :gen_tcp.close(socket)
        end

      {:error, _reason} ->
        {:error, :scanner_unavailable}
    end
  end

  defp do_instream(socket, path, chunk) do
    with :ok <- :gen_tcp.send(socket, "zINSTREAM\0"),
         :ok <- stream_chunks(socket, path, chunk),
         :ok <- :gen_tcp.send(socket, <<0::32>>),
         {:ok, response} <- recv_response(socket) do
      interpret(response)
    else
      {:error, :infected} = err ->
        err

      {:error, _} ->
        {:error, :scanner_unavailable}
    end
  end

  defp stream_chunks(socket, path, chunk) do
    path
    |> File.stream!(chunk, [])
    |> Enum.reduce_while(:ok, fn data, :ok ->
      frame = <<byte_size(data)::32, data::binary>>

      case :gen_tcp.send(socket, frame) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  rescue
    e in [File.Error] -> {:error, e}
  end

  defp recv_response(socket) do
    case :gen_tcp.recv(socket, 0, @recv_timeout) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  defp interpret(response) when is_binary(response) do
    cond do
      String.contains?(response, "OK") and not String.contains?(response, "FOUND") ->
        :clean

      String.contains?(response, "FOUND") ->
        {:error, :infected}

      true ->
        {:error, :scanner_unavailable}
    end
  end

  defp clamav_endpoint do
    opts =
      Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
      |> Keyword.get(:clamav, [])

    host = Keyword.get(opts, :host, "127.0.0.1")
    port = Keyword.get(opts, :port, 3310)
    {host, port}
  end

  defp hash_chunk do
    Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
    |> Keyword.get(:hash_chunk_bytes, @default_chunk)
  end
end
