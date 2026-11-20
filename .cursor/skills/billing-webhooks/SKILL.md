---
name: billing-webhooks
description: Apply when designing or implementing billing, subscriptions, payment provider integrations (Stripe, LemonSqueezy), webhooks, and entitlement gating.
---

# Billing, Payment Integrations & Webhook Safety

## Purpose
Protect revenue, prevent financial race conditions, maintain multi-tenant subscription integrity, and ensure resilient, replay-safe webhook processing.

## Inputs
- `docs/architecture.md`, `docs/threat-model.md`, `docs/nfr.md`, and `intent/<slug>/spec.md`

## Execution

### Invariants
- **Cryptographic Webhook Signature Verification:** Verify the raw cryptographic signature (e.g., `Stripe-Signature`, HMAC secret) on all incoming payment webhooks using raw byte payloads before parsing JSON. Reject invalid or unverified signatures immediately with an HTTP 400 error.
- **Idempotency & Event Deduplication:**
  - Persist processed webhook event IDs (`event_id`) atomically in a deduplication datastore (`processed_events`).
  - If an incoming event ID has already been successfully processed, immediately acknowledge with `200 OK` and skip duplicate business execution.
- **Out-of-Order & Replay Tolerance:**
  - Webhooks arrive asynchronously and out of order (e.g., `customer.subscription.deleted` or `updated` may arrive before `customer.subscription.created`).
  - Compare event timestamps (`created` / `event.timestamp`) against existing database entity timestamps before applying state mutations. Never overwrite a newer entity state with an older out-of-order event.
- **Server-Side Entitlement Authority:**
  - Feature access, tier limits, seat counts, and usage quotas must be enforced strictly on the server and database layer, never solely by trusting client-side claims or UI flags.
  - Store subscription status, plan tier, and billing cycle anchors in the core database; check entitlements directly during protected command and query execution.
- **Failed Payment & Dunning Lifecycles:**
  - Handle payment failures (`invoice.payment_failed`) gracefully: transition subscriptions to past-due status, trigger customer notification, and allow a grace period before revoking data access. Never delete customer data immediately on a failed recurring invoice.

### Defaults
- **Fast Webhook Acknowledgment:** Verify signatures and record the event ID in the database, then acknowledge the webhook with `200 OK` within 2–5 seconds. Offload heavy processing (generating PDFs, emailing receipts, provisioning external workspaces) to background queues.
- **Webhook Replay Testing:** Maintain automated integration tests asserting that delivering the same webhook payload twice results in exactly one state change and zero duplicate charges/credits.
- **Proration & Currency Precision:** Store monetary values as integers in the smallest currency unit (e.g., cents in USD/EUR) to prevent floating-point rounding errors.

### Decisions
- **Payment Gateway Selection:** Documented via `/record-decision` in `docs/adr/`.
- **Checkout Flow:** Host checkout sessions via provider-hosted pages (e.g., Stripe Checkout / Customer Portal) by default to eliminate PCI-DSS scope before considering custom card collection elements.

### Exceptions
- Free-tier accounts or non-monetary trial grants bypass payment gateway verification, but must still enforce quota and feature boundaries via the standard entitlement checker.
