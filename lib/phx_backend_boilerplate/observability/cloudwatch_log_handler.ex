defmodule PhxBackendBoilerplate.Observability.CloudWatchLogHandler do
  @moduledoc """
  Erlang `:logger` handler that batches log events to CloudWatch Logs.

  Never raises into the Logger path: AWS failures are throttled to the console.
  """

  @behaviour :logger_handler
  use GenServer

  alias PhxBackendBoilerplate.Logging.Redaction
  alias PhxBackendBoilerplate.Observability.CloudWatchLogsClient

  @default_flush_interval_ms 2_000
  @default_max_batch 50
  @default_error_throttle_ms 30_000

  @impl true
  def adding_handler(%{id: _id, config: config} = handler_config) do
    config = normalize_config(config)

    case GenServer.start_link(__MODULE__, config, name: __MODULE__) do
      {:ok, _pid} ->
        {:ok, handler_config}

      {:error, {:already_started, _pid}} ->
        :ok = GenServer.call(__MODULE__, {:update_config, config})
        {:ok, handler_config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def removing_handler(_handler_config) do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end
  end

  @impl true
  def changing_config(_set_or_update, _old, new) do
    {:ok, new}
  end

  @impl true
  def log(log_event, _handler_config) do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:log, log_event})
    end
  end

  @impl GenServer
  def init(config) do
    state = %{
      config: config,
      buffer: [],
      sequence_token: nil,
      ensured?: false,
      last_error_at: 0,
      timer: schedule_flush(config.flush_interval_ms)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:update_config, config}, _from, state) do
    {:reply, :ok, %{state | config: config}}
  end

  @impl GenServer
  def handle_cast({:log, log_event}, state) do
    event = encode_event(log_event)
    buffer = [event | state.buffer]
    state = %{state | buffer: buffer}

    if length(buffer) >= state.config.max_batch do
      {:noreply, flush(state)}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:flush, state) do
    state =
      state
      |> flush()
      |> Map.put(:timer, schedule_flush(state.config.flush_interval_ms))

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    _ = flush(state)
    :ok
  end

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush, interval)
  end

  defp normalize_config(config) when is_map(config) do
    log_stream =
      case Map.get(config, :log_stream) do
        nil -> default_stream_name()
        "" -> default_stream_name()
        stream -> stream
      end

    %{
      log_group: Map.fetch!(config, :log_group),
      log_stream: log_stream,
      flush_interval_ms: Map.get(config, :flush_interval_ms, @default_flush_interval_ms),
      max_batch: Map.get(config, :max_batch, @default_max_batch),
      error_throttle_ms: Map.get(config, :error_throttle_ms, @default_error_throttle_ms)
    }
  end

  defp default_stream_name do
    {:ok, host} = :inet.gethostname()
    "#{host}-#{System.pid()}"
  end

  defp encode_event(log_event) do
    %{
      "timestamp" => event_timestamp_ms(log_event),
      "message" => format_message(log_event)
    }
  end

  defp event_timestamp_ms(%{meta: %{time: time}}) when is_integer(time) do
    System.convert_time_unit(time, :microsecond, :millisecond)
  end

  defp event_timestamp_ms(_), do: System.system_time(:millisecond)

  defp format_message(%{msg: msg, meta: meta, level: level} = event) do
    text =
      case msg do
        {:string, string} ->
          to_string(string)

        {:report, report} ->
          report |> Redaction.redact() |> inspect()

        {format, args} when is_list(args) ->
          :io_lib.format(format, args) |> IO.iodata_to_binary()

        other ->
          inspect(other)
      end

    Jason.encode!(%{
      level: level,
      message: text,
      metadata: selectable_metadata(meta),
      domain: Map.get(event, :domain)
    })
  end

  defp selectable_metadata(meta) when is_map(meta) do
    meta
    |> Map.take([
      :request_id,
      :correlation_id,
      :user_id,
      :trace_id,
      :span_id,
      :otel_trace_id,
      :otel_span_id,
      :otel_trace_flags,
      :mfa,
      :file,
      :line
    ])
    |> Redaction.redact()
    |> Map.new(fn {k, v} -> {k, stringify_meta(v)} end)
  end

  defp stringify_meta(v) when is_binary(v), do: v
  defp stringify_meta(v) when is_atom(v), do: Atom.to_string(v)
  defp stringify_meta(v) when is_integer(v), do: v
  defp stringify_meta(v), do: inspect(v)

  defp flush(%{buffer: []} = state), do: state

  defp flush(state) do
    state = ensure_stream(state)
    events = Enum.reverse(state.buffer)

    case CloudWatchLogsClient.put_log_events(
           state.config.log_group,
           state.config.log_stream,
           events,
           state.sequence_token
         ) do
      {:ok, token} ->
        %{state | buffer: [], sequence_token: token}

      {:error, reason} ->
        state = maybe_report_error(state, reason)

        buffer =
          if length(state.buffer) > state.config.max_batch * 4 do
            Enum.take(state.buffer, state.config.max_batch * 2)
          else
            state.buffer
          end

        %{state | buffer: buffer}
    end
  end

  defp ensure_stream(%{ensured?: true} = state), do: state

  defp ensure_stream(state) do
    with :ok <- CloudWatchLogsClient.create_log_group(state.config.log_group),
         :ok <-
           CloudWatchLogsClient.create_log_stream(
             state.config.log_group,
             state.config.log_stream
           ) do
      %{state | ensured?: true}
    else
      {:error, reason} ->
        maybe_report_error(state, reason)
    end
  end

  defp maybe_report_error(state, reason) do
    now = System.monotonic_time(:millisecond)

    if now - state.last_error_at >= state.config.error_throttle_ms do
      IO.warn("CloudWatch Logs export failed: #{inspect(reason)}")
      %{state | last_error_at: now}
    else
      state
    end
  end
end
