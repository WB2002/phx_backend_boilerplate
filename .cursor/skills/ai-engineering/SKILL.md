---
name: ai-engineering
description: Apply when integrating AI models, LLM APIs, prompt engineering, RAG pipelines, or autonomous agent tool execution to enforce cost caps, structured output schema validation, injection defense, and deterministic fallbacks.
---

# Production AI & LLM Engineering

## Purpose
Ensure all LLM integrations, AI workflows, and RAG pipelines operate reliably, deterministically, securely, and within strict cost and latency boundaries for solo production systems.

## Inputs
- `docs/architecture.md`, `docs/nfr.md`, `docs/threat-model.md`, and `intent/<slug>/spec.md`

## Execution

### Invariants
- **Strict Schema Validation on Model Outputs:** Every model-generated output destined for application logic, database storage, external APIs, or UI rendering must be parsed and validated against a strict schema (e.g., Zod, Pydantic, JSON Schema). Never trust raw LLM output or execute unvalidated model strings directly in SQL, shell, or HTML sinks.
- **Bounded Repair Loops:** If model output fails schema validation, allow at most 1–2 automated schema repair re-prompts with explicit validation error context. If validation fails after the bounded retries, fail closed or route to a deterministic fallback. Never allow unbounded generation loops.
- **Cost, Token & Latency Budgets:**
  - Enforce explicit `max_tokens` (input and output) and request timeouts on every model API call.
  - Enforce per-user and per-tenant rate limits and monthly dollar/token budgets before dispatching requests to external AI providers.
- **Prompt Injection & Context Trust Boundaries:**
  - Clearly separate trusted instructions (system prompt / developer instructions) from untrusted inputs (user prompts, retrieved RAG context, web search results, external tool returns).
  - Wrap untrusted data in explicit delimiter tags (e.g., `<user_data>`, `<retrieved_context>`) with instructions forbidding model interpretation of data as instructions.
  - Treat all retrieved RAG and web data as untrusted third-party inputs (`untrusted_context`).
- **Data Loss Prevention (DLP) & Privacy:**
  - Scrub or redact sensitive data, credentials, and protected personal information (`PII` / `PHI`) before sending prompts or payloads to external model providers (`security-baseline`).
- **Tool-Call Authorization & Confirmation:**
  - Model tool calls that perform state mutations (database updates, emails, purchases, file deletions) must enforce server-side authorization checks and, for high-impact actions, require explicit human confirmation.

### Defaults
- **Prompt Caching & Deterministic Fallbacks:**
  - Place static system instructions and invariant tool definitions at the prefix of prompts to maximize provider prompt-caching hit rates and minimize latency/cost.
  - Configure deterministic fallbacks: if the primary model fails or times out, fall back to a smaller/faster model or a rule-based fallback response.
- **Structured Error Handling:** Catch model provider errors (`429` rate limit, `503` overloaded, token limit exceeded, safety filters triggered) and return structured, user-friendly domain errors rather than raw provider tracebacks.

### Decisions
- **Model Tiering & Routing:** Settled in `intent/<slug>/spec.md` and `docs/adr/0001-stack.md`. Route simple classification, extraction, and routing tasks to fast, low-cost models; reserve large frontier models for complex multi-step reasoning.
- **Evaluation & Drift Tracking:** Define regression test datasets / evals (`evals/cases/`) to verify prompt and output quality before updating prompt templates or model versions.

### Exceptions
- Offline development scripts and developer-facing evals may use relaxed token caps, but must still enforce timeout limits.
