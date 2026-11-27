defmodule PhxBackendBoilerplateWeb.OpenAPISpec do
  @moduledoc """
  OpenAPI 3.0.3 specification for the Phoenix backend REST API.

  Paths under `/api/*` scopes use `servers: [{url: "/api"}]` so static route
  analyzers (polyglot conformance) match Phoenix scope-relative paths.
  """

  @api_server [%{"url" => "/api"}]
  @root_server [%{"url" => "/"}]

  @spec spec() :: map()
  def spec do
    %{
      "openapi" => "3.0.3",
      "info" => %{
        "title" => "Phoenix Backend Boilerplate API",
        "version" => "0.1.0",
        "description" => "REST API specification for PhxBackendBoilerplate"
      },
      "servers" => @root_server ++ @api_server,
      "paths" => paths(),
      "components" => components()
    }
  end

  defp paths do
    probe_paths()
    |> Map.merge(auth_paths())
    |> Map.merge(demo_paths())
    |> Map.merge(billing_paths())
    |> Map.merge(webhook_paths())
  end

  defp probe_paths do
    %{
      "/health" => %{
        "get" => %{
          "servers" => @root_server,
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
          "servers" => @root_server,
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
      "/openapi.json" => %{
        "get" => %{
          "servers" => @root_server,
          "operationId" => "openApiDocument",
          "summary" => "OpenAPI specification document",
          "tags" => ["Meta"],
          "responses" => %{
            "200" => %{"description" => "OpenAPI 3.0 JSON document"},
            "404" => json_response("Disabled", %{"$ref" => "#/components/schemas/ErrorResponse"})
          }
        }
      }
    }
  end

  defp auth_paths do
    %{
      "/auth/register" => %{
        "post" => %{
          "servers" => @api_server,
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
      "/auth/login" => %{
        "post" => %{
          "servers" => @api_server,
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
      "/auth/refresh" => %{
        "post" => %{
          "servers" => @api_server,
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
      "/auth/me" => %{
        "get" => %{
          "servers" => @api_server,
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
      "/auth/logout" => %{
        "post" => %{
          "servers" => @api_server,
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
      }
    }
  end

  defp demo_paths do
    demo_get = fn operation_id, summary ->
      %{
        "servers" => @api_server,
        "operationId" => operation_id,
        "summary" => summary,
        "tags" => ["Demo"],
        "responses" => %{"200" => %{"description" => "Demo response"}}
      }
    end

    demo_post = fn operation_id, summary ->
      %{
        "servers" => @api_server,
        "operationId" => operation_id,
        "summary" => summary,
        "tags" => ["Demo"],
        "requestBody" => json_request_body(%{"type" => "object"}),
        "responses" => %{"200" => %{"description" => "Demo response"}}
      }
    end

    %{
      "/demo/login" => %{"post" => demo_post.("demoLogin", "Demo session login")},
      "/demo/comments" => %{"post" => demo_post.("demoCreateComment", "Create demo comment")},
      "/demo/public" => %{"get" => demo_get.("demoPublic", "Public demo payload")},
      "/demo/expensive" => %{"get" => demo_get.("demoExpensive", "Load-shed demo endpoint")},
      "/demo/cached" => %{"get" => demo_get.("demoCached", "Cached demo endpoint")},
      "/demo/stream/chunks" => %{"get" => demo_get.("demoStreamChunks", "Chunked stream demo")},
      "/demo/stream/sse" => %{"get" => demo_get.("demoStreamSse", "SSE stream demo")},
      "/demo/files" => %{"post" => demo_post.("demoUploadFile", "Multipart file upload demo")},
      "/demo/files/{id}" => %{
        "get" =>
          Map.put(demo_get.("demoDownloadFile", "Download demo file"), "parameters", [
            path_id_param()
          ])
      },
      "/demo/flags/preview" => %{"get" => demo_get.("demoFlagsPreview", "Feature flag preview")},
      "/demo/flags/beta" => %{"get" => demo_get.("demoFlagsBeta", "Public beta flag demo")},
      "/demo/jobs" => %{"post" => demo_post.("demoEnqueueJob", "Enqueue background job demo")}
    }
  end

  defp billing_paths do
    %{
      "/billing/plans" => %{
        "get" => %{
          "servers" => @api_server,
          "operationId" => "listBillingPlans",
          "summary" => "List available subscription plans",
          "tags" => ["Billing"],
          "responses" => %{
            "200" => json_response("Plan list", %{"type" => "object"})
          }
        }
      },
      "/billing/checkout-sessions" => %{
        "post" => %{
          "servers" => @api_server,
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
      "/billing/me" => %{
        "get" => %{
          "servers" => @api_server,
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
      }
    }
  end

  defp webhook_paths do
    %{
      "/webhooks/stripe" => %{
        "post" => %{
          "servers" => @api_server,
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

  defp path_id_param do
    %{
      "name" => "id",
      "in" => "path",
      "required" => true,
      "schema" => %{"type" => "string"}
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
