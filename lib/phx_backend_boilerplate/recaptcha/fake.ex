defmodule PhxBackendBoilerplate.Recaptcha.Fake do
  @moduledoc """
  Test double for reCAPTCHA verification.

  Defaults to `:ok`. Configure failure with:

      Application.put_env(:phx_backend_boilerplate, PhxBackendBoilerplate.Recaptcha.Fake,
        result: {:error, :verification_failed}
      )
  """

  @doc false
  def verify(_token, _opts) do
    Application.get_env(:phx_backend_boilerplate, __MODULE__, [])
    |> Keyword.get(:result, :ok)
  end
end
