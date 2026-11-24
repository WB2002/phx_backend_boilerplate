defmodule PhxBackendBoilerplate.Crypto.Config do
  @moduledoc false

  @config_key PhxBackendBoilerplate.Crypto

  @doc false
  def config(key, default \\ nil) do
    Application.get_env(:phx_backend_boilerplate, @config_key, [])
    |> Keyword.get(key, default)
  end

  @doc false
  def key_id(opts) when is_list(opts) do
    case Keyword.get(opts, :key_id) || config(:key_id) do
      id when is_binary(id) and id != "" -> {:ok, id}
      _ -> {:error, :key_id_missing}
    end
  end

  @doc false
  def context(opts) when is_list(opts) do
    case Keyword.get(opts, :context, %{}) do
      ctx when is_map(ctx) -> ctx
      _ -> %{}
    end
  end

  @doc false
  def kms_client do
    module = config(:kms, PhxBackendBoilerplate.Crypto.KMS.ExAws)
    module.new()
  end
end
