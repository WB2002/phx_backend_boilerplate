defmodule PhxBackendBoilerplateWeb.OpenAPISpec do
  @moduledoc """
  OpenAPI 3.0.3 specification for the Phoenix backend REST API.

  Used by DAST scanners (OWASP ZAP, Schemathesis) and API clients.
  """

  @spec spec() :: map()
  def spec do
    %{
      "openapi" => "3.0.3",
      "info" => %{
        "title" => "Phoenix Backend Boilerplate API",
        "version" => "0.1.0",
        "description" => "REST API specification for PhxBackendBoilerplate"
      },
      "paths" => paths(),
      "components" => components()
    }
  end

  defp paths do
    %{
      "/health" => %{
        "get" => %{
          "operationId" => "healthCheck",
          "summary" => "Liveness probe",
          "tags" => ["Health"],
          "responses" => %{
            "200" =>
              json_response("Service is healthy", %{
                "$ref" => "#/components/schemas/HealthResponse"
              })
          }
        }
      },
      "/ready" => %{
        "get" => %{
          "operationId" => "readinessCheck",
          "summary" => "Readiness probe",
          "tags" => ["Health"],
          "responses" => %{
            "200" =>
              json_response("Service is ready", %{"$ref" => "#/components/schemas/HealthResponse"}),
            "503" =>
              json_response("Dependency unavailable", %{
                "$ref" => "#/components/schemas/ErrorResponse"
              })
          }
        }
      },
      "/api/auth/register" => %{
        "post" => %{
          "operationId" => "registerUser",
          "summary" => "Register a new user account",
          "tags" => ["Auth"],
          "requestBody" => json_request_body(%{"$ref" => "#/components/schemas/AuthCredentials"}),
          "responses" => %{
            "201" =>
              json_response("Account created", %{"$ref" => "#/components/schemas/AuthResponse"}),
            "422" =>
              json_response("Validation error", %{"$ref" => "#/components/schemas/ErrorResponse"})
          }
        }
      },
      "/api/auth/login" => %{
        "post" => %{
          "operationId" => "loginUser",
          "summary" => "Authenticate with email and password",
          "tags" => ["Auth"],
          "requestBody" => json_request_body(%{"$ref" => "#/components/schemas/AuthCredentials"}),
          "responses" => %{
            "200" =>
              json_response("Authenticated", %{"$ref" => "#/components/schemas/AuthResponse"}),
            "401" =>
              json_response("Invalid credentials", %{
                "$ref" => "#/components/schemas/ErrorResponse"
              })
          }
        }
      },
      "/api/auth/refresh" => %{
        "post" => %{
          "operationId" => "refreshSession",
          "summary" => "Rotate refresh cookie and issue a new access token",
          "tags" => ["Auth"],
          "responses" => %{
            "200" =>
              json_response("Token refreshed", %{"$ref" => "#/components/schemas/AuthResponse"}),
            "401" =>
              json_response("Invalid or expired refresh token", %{
                "$ref" => "#/components/schemas/ErrorResponse"
              })
          }
        }
      },
      "/api/auth/me" => %{
        "get" => %{
          "operationId" => "currentUser",
          "summary" => "Get current authenticated user",
          "tags" => ["Auth"],
          "security" => [%{"bearerAuth" => []}],
          "responses" => %{
            "200" =>
              json_response("Current user", %{"$ref" => "#/components/schemas/UserEnvelope"}),
            "401" =>
              json_response("Unauthorized", %{"$ref" => "#/components/schemas/ErrorResponse"})
          }
        }
      },
      "/api/auth/logout" => %{
        "post" => %{
          "operationId" => "logoutUser",
          "summary" => "Revoke current session",
          "tags" => ["Auth"],
          "security" => [%{"bearerAuth" => []}],
          "responses" => %{
            "204" => %{"description" => "Session revoked"},
            "401" =>
              json_response("Unauthorized", %{"$ref" => "#/components/schemas/ErrorResponse"})
          }
        }
      },
      "/api/billing/plans" => %{
        "get" => %{
          "operationId" => "listBillingPlans",
          "summary" => "List available subscription plans",
          "tags" => ["Billing"],
          "responses" => %{
            "200" => json_response("Plan list", %{"type" => "object"})
          }
        }
      },
      "/api/billing/checkout-sessions" => %{
        "post" => %{
          "operationId" => "createCheckoutSession",
          "summary" => "Create a Stripe checkout session",
          "tags" => ["Billing"],
          "security" => [%{"bearerAuth" => []}],
          "requestBody" =>
            json_request_body(%{"$ref" => "#/components/schemas/CheckoutSessionRequest"}),
          "responses" => %{
            "201" => json_response("Checkout session created", %{"type" => "object"}),
            "401" =>
              json_response("Unauthorized", %{"$ref" => "#/components/schemas/ErrorResponse"}),
            "422" =>
              json_response("Validation error", %{"$ref" => "#/components/schemas/ErrorResponse"})
          }
        }
      },
      "/api/billing/me" => %{
        "get" => %{
          "operationId" => "getBillingStatus",
          "summary" => "Get current user billing status",
          "tags" => ["Billing"],
          "security" => [%{"bearerAuth" => []}],
          "responses" => %{
            "200" => json_response("Billing status", %{"type" => "object"}),
            "401" =>
              json_response("Unauthorized", %{"$ref" => "#/components/schemas/ErrorResponse"})
          }
        }
      },
      "/api/webhooks/stripe" => %{
        "post" => %{
          "operationId" => "stripeWebhook",
          "summary" => "Receive signed Stripe webhook events",
          "tags" => ["Webhooks"],
          "requestBody" => json_request_body(%{"type" => "object"}),
          "responses" => %{
            "200" => %{"description" => "Webhook accepted"},
            "400" =>
              json_response("Invalid webhook signature or payload", %{
                "$ref" => "#/components/schemas/ErrorResponse"
              })
          }
        }
      }
    }
  end

  defp components do
    %{
      "securitySchemes" => %{
        "bearerAuth" => %{
          "type" => "http",
          "scheme" => "bearer",
          "bearerFormat" => "JWT"
        }
      },
      "schemas" => %{
        "HealthResponse" => %{
          "type" => "object",
          "properties" => %{"status" => %{"type" => "string"}},
          "required" => ["status"]
        },
        "AuthCredentials" => %{
          "type" => "object",
          "properties" => %{
            "email" => %{"type" => "string", "format" => "email"},
            "password" => %{"type" => "string", "minLength" => 8}
          },
          "required" => ["email", "password"]
        },
        "User" => %{
          "type" => "object",
          "properties" => %{
            "id" => %{"type" => "string"},
            "email" => %{"type" => "string", "format" => "email"}
          },
          "required" => ["id", "email"]
        },
        "UserEnvelope" => %{
          "type" => "object",
          "properties" => %{"data" => %{"$ref" => "#/components/schemas/User"}},
          "required" => ["data"]
        },
        "AuthResponse" => %{
          "type" => "object",
          "properties" => %{
            "data" => %{
              "type" => "object",
              "properties" => %{
                "access_token" => %{"type" => "string"},
                "expires_in" => %{"type" => "integer"},
                "user" => %{"$ref" => "#/components/schemas/User"}
              },
              "required" => ["access_token", "expires_in", "user"]
            }
          },
          "required" => ["data"]
        },
        "CheckoutSessionRequest" => %{
          "type" => "object",
          "properties" => %{"plan" => %{"type" => "string"}},
          "required" => ["plan"]
        },
        "ErrorResponse" => %{
          "type" => "object",
          "properties" => %{"errors" => %{"type" => "object"}}
        }
      }
    }
  end

  defp json_request_body(schema) do
    %{
      "required" => true,
      "content" => %{"application/json" => %{"schema" => schema}}
    }
  end

  defp json_response(description, schema) do
    %{
      "description" => description,
      "content" => %{"application/json" => %{"schema" => schema}}
    }
  end
end
