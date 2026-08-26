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
    with {:ok, dto} <- Params.validate(CheckoutSessionDTO, params),
         user <- Accounts.get_user!(conn.assigns.current_user_id),
         {:ok, session} <- Billing.create_checkout_session(user, dto.plan) do
      conn
      |> put_status(:created)
      |> json(%{data: session})
    end
  end

  def me(conn, _params) do
    user = Accounts.get_user!(conn.assigns.current_user_id)
    json(conn, %{data: Billing.get_status(user)})
  end
end
