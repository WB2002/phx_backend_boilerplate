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
end
