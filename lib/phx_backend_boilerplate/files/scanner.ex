defmodule PhxBackendBoilerplate.Files.Scanner do
  @moduledoc """
  Virus scanning facade. Default implementation talks to ClamAV (fail-closed).

  Swap via `config :phx_backend_boilerplate, PhxBackendBoilerplate.Files, scanner: Module`.
  """

  @callback scan_file(path :: Path.t()) ::
              :clean | {:error, :infected} | {:error, :scanner_unavailable} | {:error, term()}

  @doc """
  Scans the file at `path`. Streams contents — never loads the whole file.
  """
  @spec scan_file(Path.t()) ::
          :clean | {:error, :infected} | {:error, :scanner_unavailable} | {:error, term()}
  def scan_file(path) when is_binary(path), do: impl().scan_file(path)

  defp impl do
    Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
    |> Keyword.get(:scanner, PhxBackendBoilerplate.Files.Scanner.ClamAV)
  end

  @doc false
  @spec skip_allowed?(atom()) :: boolean()
  def skip_allowed?(:dev), do: true
  def skip_allowed?(_env), do: false

  @doc false
  @spec resolve_skip_scanner(atom(), boolean()) ::
          {:ok, module()} | {:ok, :unchanged} | {:error, :skip_not_allowed}
  def resolve_skip_scanner(_env, false), do: {:ok, :unchanged}
  def resolve_skip_scanner(:dev, true), do: {:ok, PhxBackendBoilerplate.Files.Scanner.AlwaysClean}
  def resolve_skip_scanner(:test, true), do: {:ok, :unchanged}
  def resolve_skip_scanner(_env, true), do: {:error, :skip_not_allowed}
end
