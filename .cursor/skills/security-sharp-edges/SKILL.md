---
name: security-sharp-edges
description: Use when designing or implementing configuration parsing, authentication helpers, database queries, multi-tenant contexts, cryptography, or internal APIs to eliminate fail-open insecure defaults and misuse-prone sharp edges.
---

# Security Sharp Edges & Insecure Defaults (Trail of Bits Pattern)

## Overview
Most production security breaches come not from exotic zero-days, but from **insecure fail-open defaults** and **misuse-prone internal APIs ("sharp edges")** where a developer or AI agent can accidentally forget a security check. Secure usage must be the path of least resistance (the **pit of success**).

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use
- Reading environment variables, secrets, feature flags, or boot configuration.
- Designing or calling internal service functions, repository methods, or auth helpers.
- Writing `try/catch` error handlers around permissions, rate limits, webhooks, or token validation.
- Configuring CORS, cookies, TLS, HTTP clients, or serialization/parsing.

## Mandatory Rules

### 1. Ban Fail-Open Insecure Defaults (`insecure-defaults`)
- **No Fallback Secrets or Keys:** Never write `process.env.JWT_SECRET || 'default-secret'` or fall back to a hardcoded key when an environment variable is missing. Fail closed at application boot if any required secret or security config is unset.
- **No Fail-Open Catch Blocks:** A `catch` block around authentication, authorization, signature verification, rate-limiting, or DLP/policy checks must **deny access (`fail closed`)**, never log-and-continue (`return true` / `next()`).
- **No Permissive Wildcards by Default:** Never default CORS `Access-Control-Allow-Origin` to `*` on authenticated routes, never set `rejectUnauthorized: false` / `InsecureSkipVerify: true` on TLS clients, and never leave outbound HTTP/database calls without an explicit timeout.
- **No Debug/Admin Modes Defaulting to On:** Debug endpoints, verbose stack traces, or auth-bypass switches must be impossible to activate when `NODE_ENV`/`APP_ENV` is unset or unknown.

### 2. Design Misuse-Resistant Internal APIs (`sharp-edges`)
- **Make Tenant & Auth Context Unforgettable:** Never design a multi-tenant data-access function where `tenantId` is an optional parameter (`findUsers(filter, tenantId?)`). Require a non-nullable, type-checked `TenantContext` or `AuthenticatedPrincipal` as the first argument (`findUsers(ctx: TenantContext, filter)`).
- **Separate Unvalidated from Validated Types:** Parse untrusted input at the boundary into distinct branded/domain types (e.g., `ValidatedWebhookPayload`, `SanitizedHtml`, `AllowlistedUrl`) so downstream sinks cannot accidentally accept raw user strings.
- **No Boolean Security Trap Parameters:** Never design APIs like `verifyToken(token, true)` where a boolean flag skips signature or expiration checks (`skipVerification = false`). If an unverified decode is genuinely needed for inspection, name the function explicitly (`decodeUnverifiedTokenHeaderForLoggingOnly`).
- **Safe Cryptographic Defaults:** Expose high-level domain helpers (`hashPassword(plain)`, `encryptRecord(ctx, payload)`) with pinned modern algorithms (`Argon2id`, `AES-256-GCM`) rather than letting callers pass algorithm strings (`alg: string`) that invite downgrade or `"none"` algorithm attacks.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "The fallback secret is only used in local dev if `.env` is missing." | If a production deploy misconfigures the env var, the app boots silently with a public hardcoded key. Crash at boot instead. |
| "Every caller remembers to pass `tenantId` in the query filter." | One forgotten filter in one endpoint causes a cross-tenant data breach. Encode `TenantContext` in the function signature or RLS policy. |
| "If the rate-limiter / policy service times out, we should let the request through so UX isn't hurt." | Failing open on security or authz checks turns a dependency hiccup into a full security bypass. Fail closed on security boundaries. |

## Red Flags — STOP and Refactor
- `process.env.<SECRET_OR_AUTH_VAR> || ...` or `os.getenv("<SECRET>", "default")`
- A multi-tenant repository query with no mandatory `tenantId` / `TenantContext` parameter
- A `catch` block in an auth, permission, or webhook verifier that returns success or calls `next()`
- Raw string concatenation into SQL, shell, URL, or template sinks
- An outbound `fetch` / HTTP request without an explicit timeout and SSRF URL check
