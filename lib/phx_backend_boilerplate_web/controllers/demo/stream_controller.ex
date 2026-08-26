defmodule PhxBackendBoilerplateWeb.Demo.StreamController do
  @moduledoc """
  Demo endpoints for native HTTP chunked streaming and Server-Sent Events (SSE).

  No third-party streaming libraries — Phoenix/Bandit + `Plug.Conn.send_chunked/2`
  and `Plug.Conn.chunk/2` are enough. The controller process **owns** the connection
  for the lifetime of the stream.

  Query params:

    * `count` — number of payload events (default `3`, max `10`)
    * `interval_ms` — sleep between chunks (default `0`, max `200`)

  For long-lived PubSub-driven SSE, replace the enumerable loop with roughly:

      Phoenix.PubSub.subscribe(PhxBackendBoilerplate.PubSub, "topic")

      # after send_chunked/2:
      receive do
        {:event, payload} -> chunk(conn, encode_sse(...)); ...
      after
        30_000 -> chunk(conn, ": ping\\n\\n"); ...
      end

  Long-lived streams may also need a higher Bandit `idle_timeout` on the endpoint.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.Deadline

  @max_count 10
  @default_count 3
  @max_interval_ms 200

  @doc """
  Streams newline-delimited JSON (`application/x-ndjson`).
  """
  def chunks(conn, params) do
    {count, interval_ms} = parse_opts(params)

    conn =
      conn
      |> put_resp_content_type("application/x-ndjson")
      |> send_chunked(200)

    Enum.reduce_while(1..count, conn, fn seq, conn ->
      if Deadline.expired?() do
        {:halt, conn}
      else
        maybe_sleep(interval_ms)

        line =
          Jason.encode!(%{
            seq: seq,
            t: System.system_time(:millisecond)
          }) <> "\n"

        case chunk(conn, line) do
          {:ok, conn} -> {:cont, conn}
          {:error, :closed} -> {:halt, conn}
        end
      end
    end)
  end

  @doc """
  Streams Server-Sent Events (`text/event-stream`).
  """
  def sse(conn, params) do
    {count, interval_ms} = parse_opts(params)

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    case Enum.reduce_while(1..count, {:ok, conn}, &sse_tick(&1, &2, interval_ms)) do
      {:ok, conn} ->
        case chunk(conn, "event: done\ndata: {}\n\n") do
          {:ok, conn} -> conn
          {:error, :closed} -> conn
        end

      {_reason, conn} ->
        conn
    end
  end

  defp sse_tick(seq, {:ok, conn}, interval_ms) do
    if Deadline.expired?() do
      {:halt, {:deadline, conn}}
    else
      maybe_sleep(interval_ms)

      with {:ok, conn} <- maybe_keepalive(conn, interval_ms),
           {:ok, conn} <- chunk_tick(conn, seq) do
        {:cont, {:ok, conn}}
      else
        {:error, :closed, conn} -> {:halt, {:closed, conn}}
      end
    end
  end

  defp maybe_keepalive(conn, interval_ms) when interval_ms > 0 do
    # Comment frame doubles as keep-alive when pacing the stream.
    case chunk(conn, ": ping\n\n") do
      {:ok, conn} -> {:ok, conn}
      {:error, :closed} -> {:error, :closed, conn}
    end
  end

  defp maybe_keepalive(conn, _interval_ms), do: {:ok, conn}

  defp chunk_tick(conn, seq) do
    payload =
      Jason.encode!(%{
        seq: seq,
        t: System.system_time(:millisecond)
      })

    frame = "id: #{seq}\nevent: tick\ndata: #{payload}\n\n"

    case chunk(conn, frame) do
      {:ok, conn} -> {:ok, conn}
      {:error, :closed} -> {:error, :closed, conn}
    end
  end

  defp maybe_sleep(0), do: :ok
  defp maybe_sleep(ms) when ms > 0, do: Process.sleep(ms)

  defp parse_opts(params) do
    {parse_positive_int(params, "count", :count, @default_count, @max_count),
     parse_non_neg_int(params, "interval_ms", :interval_ms, 0, @max_interval_ms)}
  end

  defp parse_positive_int(params, str_key, atom_key, default, max) do
    raw = Map.get(params, str_key) || Map.get(params, atom_key)

    case Integer.parse(to_string(raw || default)) do
      {n, _} when n > 0 -> min(n, max)
      _ -> default
    end
  end

  defp parse_non_neg_int(params, str_key, atom_key, default, max) do
    raw = Map.get(params, str_key) || Map.get(params, atom_key)

    case Integer.parse(to_string(raw || default)) do
      {n, _} when n > 0 -> min(n, max)
      {0, _} -> 0
      _ -> default
    end
  end
end
