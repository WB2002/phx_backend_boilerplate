defmodule PhxBackendBoilerplateWeb.SocketAuth do
  @moduledoc """
  Signs and verifies Phoenix.Token values for websocket connect auth.

  Tokens carry a map payload `%{"sub" => user_id, "email" => email}` and
  default to a 24-hour max age.
  """

  @salt "user socket"
  @max_age 86_400

  @type claims :: %{required(String.t()) => String.t()}

  @doc """
  Signs socket claims. `claims` must include string keys `"sub"` and `"email"`.
  """
  @spec sign(claims()) :: String.t()
  def sign(%{"sub" => sub, "email" => email} = claims)
      when is_binary(sub) and is_binary(email) do
    Phoenix.Token.sign(PhxBackendBoilerplateWeb.Endpoint, @salt, claims)
  end

  @doc """
  Verifies a socket token.

  Options:
    * `:max_age` — seconds (default #{@max_age})
  """
  @spec verify(String.t(), keyword()) :: {:ok, claims()} | {:error, atom()}
  def verify(token, opts \\ []) when is_binary(token) do
    max_age = Keyword.get(opts, :max_age, @max_age)

    case Phoenix.Token.verify(PhxBackendBoilerplateWeb.Endpoint, @salt, token, max_age: max_age) do
      {:ok, %{"sub" => sub, "email" => email} = claims}
      when is_binary(sub) and is_binary(email) ->
        {:ok, claims}

      {:ok, _} ->
        {:error, :invalid}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
