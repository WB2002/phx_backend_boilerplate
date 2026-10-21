defmodule PhxBackendBoilerplate.Accounts.Config do
  @moduledoc false

  @app :phx_backend_boilerplate
  @key PhxBackendBoilerplate.Accounts

  @doc """
  Validates auth TTL configuration at boot.

  Deny-list TTL must be >= access token TTL so logout revocation covers
  in-flight access JWTs.
  """
  @spec validate!() :: :ok
  def validate! do
    access_ttl = fetch!(:access_ttl)
    deny_list_ttl = fetch!(:deny_list_ttl)

    if deny_list_ttl < access_ttl do
      raise ArgumentError,
            "Accounts deny_list_ttl (#{deny_list_ttl}ms) must be >= access_ttl (#{access_ttl}ms)"
    end

    :ok
  end

  @doc false
  def deny_list_ttl_ms do
    fetch!(:deny_list_ttl)
  end

  defp fetch!(key) do
    Application.fetch_env!(@app, @key) |> Keyword.fetch!(key)
  end
end
