defmodule PhxBackendBoilerplateWeb.BillingController do
  @moduledoc """
  Stripe Checkout billing endpoints.
  """

  use PhxBackendBoilerplateWeb, :controller

  alias PhxBackendBoilerplate.Accounts
  alias PhxBackendBoilerplate.Billing
  alias PhxBackendBoilerplateWeb.Billing.CheckoutSessionDTO
  alias PhxBackendBoilerplateWeb.Params

  action_fallback PhxBackendBoilerplateWeb.FallbackController

  def plans(conn, _params) do
    json(conn, %{data: Billing.list_plans()})
  end

  def create_checkout_session(conn, params) do
    case Accounts.get_user(conn.assigns.current_user_id) do
      nil ->
        unauthorized(conn)

      user ->
        with {:ok, dto} <- Params.validate(CheckoutSessionDTO, params),
             {:ok, session} <- Billing.create_checkout_session(user, dto.plan) do
          conn
          |> put_status(:created)
          |> json(%{data: session})
        end
    end
  end

  def me(conn, _params) do
    case Accounts.get_user(conn.assigns.current_user_id) do
      nil ->
        unauthorized(conn)

      user ->
        json(conn, %{data: Billing.get_status(user)})
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{errors: %{detail: "Unauthorized"}})
  end
end
