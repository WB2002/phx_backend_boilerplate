---
name: security-baseline
description: Apply baseline security, threat-modeling, and zero-trust egress/DLP rules when creating or changing endpoints, auth, data handling, external API/AI calls, config, or dependencies.
---

# Security Baseline & Zero-Trust Controls

## Purpose
Enforce defense-in-depth across authentication, authorization, tenant isolation, input trust boundaries, outbound egress/DLP, and secrets hygiene on every change.

## Inputs
- `docs/threat-model.md`, `.cursor/policies/security.yaml`, and `intent/<slug>/spec.md`

## Execution

### Invariants
- **Threat Model Alignment:** Read `docs/threat-model.md` whenever a change crosses a trust boundary, adds an entry point, or handles sensitive data. Call out any unmitigated abuse case in your summary.
- **Secrets & Credential Isolation:** Never place secrets, API keys, tokens, private keys, or production connection strings in code, tests, fixtures, logs, or fallback defaults. (Enforced mechanically by `.cursor/hooks/block-secrets.sh` and CI secret scanning).
- **AuthN & AuthZ on Every Boundary:** Every non-public endpoint, RPC, and background action requires verified authentication AND server-side object/tenant authorization (`BOLA`/`IDOR` prevention). Client-side UI checks are never security controls.
- **Boundary Input Validation:** Parse and validate all untrusted inputs (HTTP payloads, headers, webhook signatures, file uploads, CLI args, LLM outputs) against strict allowlist schemas at the boundary. Use parameterized queries exclusively; never interpolate raw strings into SQL, shell commands, templates, or HTML sinks.
- **Zero Sensitive Data in Telemetry:** Never log `PII`, `PHI`, passwords, session identifiers, JWTs, payment data, or raw authorization headers in logs, traces, error reports, or URL query parameters.
- **Zero-Trust Outbound Egress & DLP Guardrails (Cloudflare Pattern):**
  - Validate outbound URLs against an explicit allowlist and block private/loopback/cloud-metadata IP ranges (`169.254.169.254`, `10.0.0.0/8`, `127.0.0.0/8`, `fd00::/8`) to prevent SSRF and data exfiltration.
  - Scrub or redact secrets, `PII`, and `PHI` before transmitting prompts or payloads to external AI/LLM providers or third-party APIs (Data Loss Prevention).
- **Dependency Hygiene:** Never add or upgrade a dependency outside `/add-dependency`.

### Defaults
- Enforce short-lived tokens, `HttpOnly`/`Secure`/`SameSite` cookies, strict CORS origin allowlists, Content-Security-Policy (CSP), HSTS, and `X-Content-Type-Options: nosniff`.
- Apply edge/ingress rate limiting (per-IP, per-user, and per-tenant) and strict request body size caps before invoking expensive compute or database queries.
- Use modern cryptographic primitives (`Argon2id` for password hashing, `AES-256-GCM` or `ChaCha20-Poly1305` for encryption, `crypto.timingSafeEqual` for secret comparison).
- Pair with `security-sharp-edges` during implementation and `/security-audit` for multi-phase adversarial verification.

### Decisions
- **Multi-tenancy isolation mechanism (RLS vs. application-enforced scoped context vs. physical DB isolation):** Settled in `docs/architecture.md` and `docs/threat-model.md`.
- **AI/Agent tool-call permissions:** Any LLM or MCP tool integration must use least-privilege scoped identities and require human confirmation before mutating state or executing external actions.

### Exceptions
- Security and privacy concessions belong exclusively to the human owner (`docs/governance.md`). An agent must never waive a `security-baseline` invariant.
- Mention which baseline controls and `docs/threat-model.md` sections you verified in your completion summary.
