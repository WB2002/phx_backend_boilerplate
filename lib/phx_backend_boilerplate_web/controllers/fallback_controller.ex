defmodule PhxBackendBoilerplateWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  Controllers that use DTO validation should set:

      action_fallback PhxBackendBoilerplateWeb.FallbackController
  """

  use PhxBackendBoilerplateWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: PhxBackendBoilerplateWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{errors: %{detail: "Not Found"}})
  end

  def call(conn, {:error, :checksum_mismatch}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "Checksum mismatch", fields: %{"sha256" => ["does not match"]}}})
  end

  def call(conn, {:error, :infected}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "File failed virus scan"}})
  end

  def call(conn, {:error, :scanner_unavailable}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{errors: %{detail: "Virus scanner unavailable"}})
  end

  def call(conn, {:error, {tag, message}})
      when tag in [
             :too_few_files,
             :too_many_files,
             :file_too_large,
             :empty_file,
             :invalid_extension,
             :invalid_content_type,
             :mime_mismatch,
             :invalid_magic,
             :magic_mismatch
           ] and is_binary(message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      errors: %{
        detail: "Unprocessable Entity",
        fields: %{"files" => [message]}
      }
    })
  end

  def call(conn, {:error, {:scanner_error, _reason}}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{errors: %{detail: "Virus scanner unavailable"}})
  end

  def call(conn, {:error, {:storage_error, _reason}}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{errors: %{detail: "Storage error"}})
  end

  def call(conn, {:error, :invalid_plan}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "Invalid plan", fields: %{"plan" => ["is invalid"]}}})
  end

  def call(conn, {:error, :misconfigured}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{errors: %{detail: "Billing is not configured"}})
  end

  def call(conn, {:error, :skipped}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{errors: %{detail: "Billing is disabled"}})
  end

  def call(conn, {:error, :queue_full}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{errors: %{detail: "Too Many Requests"}})
  end

  def call(conn, {:error, :unique}) do
    conn
    |> put_status(:conflict)
    |> json(%{errors: %{detail: "Duplicate job"}})
  end

  def call(conn, {:error, _reason}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{detail: "Unprocessable Entity"}})
  end
end
