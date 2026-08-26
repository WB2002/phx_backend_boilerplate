defmodule PhxBackendBoilerplate.Files.Storage do
  @moduledoc """
  Object storage facade. Default is local disk; set `STORAGE_BACKEND=s3` for S3.

  All operations stream — never load whole objects into memory.
  """

  @type key :: String.t()
  @type stream_chunk :: binary()

  @callback put(key, path :: Path.t()) :: :ok | {:error, term()}
  @callback delete(key) :: :ok | {:error, term()}
  @callback stream(key, offset :: non_neg_integer(), length :: non_neg_integer() | :eof) ::
              {:ok, Enumerable.t()} | {:error, term()}
  @callback local_path(key) :: Path.t() | nil

  @doc "Store file at `path` under `key` by streaming from disk."
  @spec put(key, Path.t()) :: :ok | {:error, term()}
  def put(key, path), do: impl().put(key, path)

  @doc "Delete object at `key`."
  @spec delete(key) :: :ok | {:error, term()}
  def delete(key), do: impl().delete(key)

  @doc """
  Stream bytes from `key` starting at `offset` for `length` bytes (`:eof` = rest).
  """
  @spec stream(key, non_neg_integer(), non_neg_integer() | :eof) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def stream(key, offset, length), do: impl().stream(key, offset, length)

  @doc """
  Absolute filesystem path when the backend is local; `nil` for remote backends.
  Used to serve via `Plug.Conn.send_file/5`.
  """
  @spec local_path(key) :: Path.t() | nil
  def local_path(key), do: impl().local_path(key)

  @doc "Backend module name atom for persistence (`\"local\"` / `\"s3\"`)."
  @spec backend_name() :: String.t()
  def backend_name do
    case impl() do
      PhxBackendBoilerplate.Files.Storage.S3 -> "s3"
      _ -> "local"
    end
  end

  defp impl do
    Application.get_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Files, [])
    |> Keyword.get(:storage, PhxBackendBoilerplate.Files.Storage.Local)
  end
end
