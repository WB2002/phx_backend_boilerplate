defmodule PhxBackendBoilerplate.Logging.Redaction do
  @moduledoc """
  Field redaction for logs: secrets (`:redacted`) and personal data (`:pii`).

  Both sets are treated the same in the logger — matching **keys** (exact match
  after `to_string/1`) have values replaced with `"[REDACTED]"`.

  Configure in `config/config.exs` via `config/redaction_keys.exs`:

      config :phx_backend_boilerplate, PhxBackendBoilerplate.Logging.Redaction,
        redacted: [...],
        pii: [...]

  Free-text log messages are **not** scanned. Prefer keyed metadata or maps.
  """

  @replacement "[REDACTED]"

  @doc "Union of redacted and PII keys as strings (for LoggerJSON / Phoenix)."
  def keys do
    cfg = Application.get_env(:phx_backend_boilerplate, __MODULE__, [])

    (Keyword.get(cfg, :redacted, []) ++ Keyword.get(cfg, :pii, []))
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
  end

  @doc "LoggerJSON redactor list wired to `keys/0`."
  def redactors do
    [{LoggerJSON.Redactors.RedactKeys, keys()}]
  end

  @doc """
  Recursively redacts map / keyword values whose keys are in `keys/0`.

  Structs are left intact (avoids mutating `%Plug.Conn{}` and crash structs).
  """
  def redact(term), do: do_redact(term, MapSet.new(keys()))

  defp do_redact(%_{} = struct, _keys), do: struct

  defp do_redact(%{} = map, keys) do
    Map.new(map, fn {k, v} ->
      if MapSet.member?(keys, to_string(k)) do
        {k, @replacement}
      else
        {k, do_redact(v, keys)}
      end
    end)
  end

  defp do_redact([{key, _} | _] = keyword, keys) when is_atom(key) do
    Enum.map(keyword, fn
      {k, v} when is_atom(k) or is_binary(k) ->
        if MapSet.member?(keys, to_string(k)) do
          {k, @replacement}
        else
          {k, do_redact(v, keys)}
        end

      other ->
        do_redact(other, keys)
    end)
  rescue
    _ -> Enum.map(keyword, &do_redact(&1, keys))
  end

  defp do_redact(list, keys) when is_list(list) do
    Enum.map(list, &do_redact(&1, keys))
  end

  defp do_redact(other, _keys), do: other
end
