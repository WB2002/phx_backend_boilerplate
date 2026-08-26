defmodule PhxBackendBoilerplate.Integrations.Stripe.Signature do
  @moduledoc """
  Verifies Stripe webhook `Stripe-Signature` headers.

  See https://docs.stripe.com/webhooks/signatures
  """

  @default_tolerance 300

  @doc """
  Verifies `payload` against the `Stripe-Signature` header value.

  Returns `:ok` or `{:error, reason}` where reason is one of
  `:missing_header`, `:missing_timestamp`, `:missing_signature`,
  `:timestamp_out_of_tolerance`, or `:invalid_signature`.
  """
  @spec verify(String.t(), String.t() | nil, keyword()) :: :ok | {:error, atom()}
  def verify(payload, signature_header, opts \\ [])

  def verify(payload, signature_header, opts)
      when is_binary(payload) and is_binary(signature_header) and is_list(opts) do
    secret = Keyword.fetch!(opts, :secret)
    tolerance = Keyword.get(opts, :tolerance, @default_tolerance)
    now = Keyword.get(opts, :now, System.system_time(:second))

    with {:ok, timestamp} <- parse_timestamp(signature_header),
         :ok <- check_tolerance(timestamp, now, tolerance),
         {:ok, v1_signatures} <- parse_v1_signatures(signature_header),
         :ok <- check_signatures(payload, timestamp, secret, v1_signatures) do
      :ok
    end
  end

  def verify(_payload, nil, _opts), do: {:error, :missing_header}
  def verify(_payload, "", _opts), do: {:error, :missing_header}

  defp parse_timestamp(header) do
    header
    |> String.split(",", trim: true)
    |> Enum.find_value({:error, :missing_timestamp}, fn part ->
      case String.split(part, "=", parts: 2) do
        ["t", timestamp] when timestamp != "" -> {:ok, timestamp}
        _ -> nil
      end
    end)
  end

  defp check_tolerance(timestamp, now, tolerance) do
    case Integer.parse(timestamp) do
      {ts, ""} ->
        if abs(now - ts) <= tolerance do
          :ok
        else
          {:error, :timestamp_out_of_tolerance}
        end

      _ ->
        {:error, :missing_timestamp}
    end
  end

  defp parse_v1_signatures(header) do
    signatures =
      header
      |> String.split(",", trim: true)
      |> Enum.flat_map(fn
        "v1=" <> signature when signature != "" -> [signature]
        _ -> []
      end)

    if signatures == [] do
      {:error, :missing_signature}
    else
      {:ok, signatures}
    end
  end

  defp check_signatures(payload, timestamp, secret, signatures) do
    expected =
      :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{payload}")
      |> Base.encode16(case: :lower)

    if Enum.any?(signatures, &secure_compare(&1, expected)) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp secure_compare(left, right) when is_binary(left) and is_binary(right) do
    byte_size(left) == byte_size(right) and Plug.Crypto.secure_compare(left, right)
  end
end
