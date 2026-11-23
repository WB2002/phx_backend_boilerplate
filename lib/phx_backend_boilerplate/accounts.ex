defmodule PhxBackendBoilerplate.Accounts do
  @moduledoc """
  Email/password authentication with DB-backed rolling sessions and stateless JWTs.
  """

  import Ecto.Query, warn: false

  alias PhxBackendBoilerplate.Accounts.ExpiredSessions
  alias PhxBackendBoilerplate.Accounts.Session
  alias PhxBackendBoilerplate.Accounts.Tokens
  alias PhxBackendBoilerplate.Accounts.User
  alias PhxBackendBoilerplate.Crypto.Digest
  alias PhxBackendBoilerplate.Repo
  alias PhxBackendBoilerplateWeb.Endpoint

  @type auth_bundle :: %{
          user: User.t(),
          session: Session.t(),
          access_token: String.t(),
          refresh_token: String.t(),
          expires_in: non_neg_integer()
        }

  @doc """
  Registers a user, creates a session, and issues access + refresh tokens.
  """
  @spec register(map()) :: {:ok, auth_bundle()} | {:error, Ecto.Changeset.t()}
  def register(attrs) when is_map(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} -> create_auth_bundle(user)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Authenticates by email/password, creates a session, and issues tokens.
  """
  @spec login(String.t(), String.t()) :: {:ok, auth_bundle()} | {:error, :invalid_credentials}
  def login(email, password) when is_binary(email) and is_binary(password) do
    if byte_size(password) > Digest.max_plaintext_bytes() do
      {:error, :invalid_credentials}
    else
      do_login(email, password)
    end
  end

  defp do_login(email, password) do
    normalized_email = String.downcase(String.trim(email))

    case Repo.get_by(User, email: normalized_email) do
      %User{} = user ->
        if Digest.verify(password, user.password_digest) do
          create_auth_bundle(user)
        else
          {:error, :invalid_credentials}
        end

      nil ->
        Digest.dummy_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Validates a refresh token, rotates the refresh identifier, rolls the session
  inactivity window, and re-issues tokens.

  Reuse of a previously rotated refresh token revokes the session family.
  """
  @spec refresh(String.t()) ::
          {:ok, auth_bundle()} | {:error, :invalid_token | :session_expired | :session_not_found}
  def refresh(refresh_token) when is_binary(refresh_token) do
    with {:ok, claims} <- Tokens.verify_refresh(refresh_token),
         {:ok, bundle} <- refresh_in_transaction(claims) do
      {:ok, bundle}
    else
      {:error, :not_found} ->
        {:error, :session_not_found}

      {:error, :expired} ->
        {:error, :session_expired}

      {:error, :refresh_token_reused} ->
        logout(claims["jti"])
        {:error, :session_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes the session row, then best-effort writes the id to the Redis deny list.

  Always returns `:ok` even when the cache write fails; Postgres delete is the
  durable revocation step.
  """
  @spec logout(String.t()) :: :ok
  def logout(session_id) when is_binary(session_id) do
    session = Repo.get(Session, session_id)
    Repo.delete_all(from s in Session, where: s.id == ^session_id)
    ExpiredSessions.revoke(session_id)

    if session do
      disconnect_graphql_socket(session.user_id, session_id)
    end

    :ok
  end

  @doc """
  Verifies an access JWT and returns user/session ids when the session is not revoked.

  Used by HTTP plugs and GraphQL sockets so auth logic stays in one place.
  """
  @spec authenticate_access_token(String.t()) ::
          {:ok, %{user_id: String.t(), session_id: String.t()}} | {:error, :unauthorized}
  def authenticate_access_token(token) when is_binary(token) do
    with {:ok, claims} <- Tokens.verify_access(token),
         false <- ExpiredSessions.revoked?(claims["jti"]) do
      {:ok, %{user_id: claims["sub"], session_id: claims["jti"]}}
    else
      _ -> {:error, :unauthorized}
    end
  end

  @doc """
  Resolves a session id from an access or refresh token (for logout).
  """
  @spec session_id_from_token(String.t(), :access | :refresh) ::
          {:ok, String.t()} | {:error, :invalid_token}
  def session_id_from_token(token, type) when is_binary(token) and type in [:access, :refresh] do
    verification =
      case type do
        :access -> Tokens.verify_access(token)
        :refresh -> Tokens.verify_refresh(token)
      end

    case verification do
      {:ok, %{"jti" => session_id}} when is_binary(session_id) ->
        {:ok, session_id}

      _ ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Fetches a user by id, or `nil` when no row exists.
  """
  @spec get_user(String.t()) :: User.t() | nil
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Fetches a user by id, raising when no row exists.
  """
  @spec get_user!(String.t()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  defp create_auth_bundle(%User{} = user) do
    with {:ok, session} <- insert_session(user) do
      issue_tokens(session)
    end
  end

  defp insert_session(%User{id: user_id}) do
    %Session{user_id: user_id, refresh_token_id: Ecto.UUID.generate()}
    |> Session.changeset(%{expires_at: session_expires_at()})
    |> Repo.insert()
  end

  defp refresh_in_transaction(%{"jti" => session_id, "rti" => presented_rti}) do
    Repo.transaction(fn ->
      session =
        Session
        |> where([s], s.id == ^session_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      case session do
        nil ->
          Repo.rollback(:not_found)

        %Session{} = locked ->
          now = DateTime.utc_now(:second)

          cond do
            DateTime.compare(locked.expires_at, now) != :gt ->
              Repo.rollback(:expired)

            locked.refresh_token_id != presented_rti ->
              disconnect_graphql_socket(locked.user_id, session_id)
              Repo.delete_all(from s in Session, where: s.id == ^session_id)
              ExpiredSessions.revoke(session_id)
              Repo.rollback(:refresh_token_reused)

            true ->
              case rotate_refresh_token(locked) do
                {:ok, rotated} ->
                  {:ok, bundle} = issue_tokens(rotated)
                  bundle

                {:error, changeset} ->
                  Repo.rollback(changeset)
              end
          end
      end
    end)
    |> case do
      {:ok, bundle} -> {:ok, bundle}
      {:error, reason} -> {:error, reason}
    end
  end

  defp rotate_refresh_token(%Session{} = session) do
    session
    |> Ecto.Changeset.change(%{
      expires_at: session_expires_at(),
      refresh_token_id: Ecto.UUID.generate()
    })
    |> Repo.update()
  end

  defp issue_tokens(%Session{} = session) do
    session = Repo.preload(session, :user)
    user = session.user

    access_token = Tokens.generate_access_token(user.id, session.id)
    refresh_token = Tokens.generate_refresh_token(user.id, session)

    {:ok,
     %{
       user: user,
       session: session,
       access_token: access_token,
       refresh_token: refresh_token,
       expires_in: Tokens.access_ttl_seconds()
     }}
  end

  defp session_expires_at do
    inactivity_ttl =
      accounts_config()
      |> Keyword.fetch!(:session_inactivity_ttl)
      |> div(1_000)

    DateTime.utc_now(:second) |> DateTime.add(inactivity_ttl, :second)
  end

  defp disconnect_graphql_socket(user_id, session_id)
       when is_binary(user_id) and is_binary(session_id) do
    Endpoint.broadcast("graphql_socket:#{user_id}:#{session_id}", "disconnect", %{})
  end

  defp accounts_config do
    Application.fetch_env!(:phx_backend_boilerplate, PhxBackendBoilerplate.Accounts)
  end
end
