---
name: resilience
description: Apply resilience, fault tolerance, circuit breaking, retry with backoff, poison pill isolation, and graceful shutdown rules when designing or implementing network, queue, cache, or external service interactions.
---

# Resilience, Fault Tolerance & Concurrency Safety

## Purpose
Prevent cascading outages, resource starvation, retry storms, stuck workers, and data corruption when external dependencies, databases, queues, or network links experience latency or failures.

## Inputs
- `docs/architecture.md`, `docs/nfr.md`, `docs/threat-model.md`, and `intent/<slug>/spec.md`

## Execution

### Invariants
- **Fault Isolation & Timeouts on Every Network Call:** Every outbound call (HTTP, RPC, database, cache, third-party API, LLM) must have an explicit connection timeout and read/request timeout budget. Never allow an upstream hang to tie up server workers indefinitely.
- **Circuit Breaking on External Services:** Wrap external service calls (payment gateways, third-party APIs, email/SMS, AI providers) in circuit breakers. When failure rates or latency thresholds exceed limits, fail fast immediately rather than queuing callers.
- **Strict Retry Semantics with Full Jitter:**
  - **Retry only transient, idempotent errors:** HTTP `429` (respecting `Retry-After`), `502`, `503`, `504`, network timeouts, and connection resets.
  - **Never retry non-transient client errors:** `400`, `401`, `403`, `404`, `422`, or domain validation failures.
  - **Full jitter backoff mandatory:** Compute backoff using full jitter (`sleep = uniform(0, min(max_backoff, base * 2^attempt))`) to prevent synchronized thundering-herd retry bursts.
- **Poison-Pill & Dead-Letter Queue (DLQ) Isolation:** Background consumers and queue processors must bound retry attempts. Messages that fail repeatedly must route to a Dead-Letter Queue (DLQ) with error metadata rather than looping infinitely and blocking the queue.
- **Distributed Lock Leases & Concurrency Bounds:** Distributed locks (Redis, Postgres advisory locks) must include mandatory lease expiration TTLs. Never create an unexpiring lock that can deadlock forever if a node crashes mid-operation.
- **Graceful Shutdown (`SIGTERM` / `SIGINT`):**
  1. Stop accepting new ingress connections / HTTP requests.
  2. Drain in-flight requests and background consumer tasks within a bounded grace period (e.g., 15–30s).
  3. Close database pools, Redis connections, and open file descriptors before process termination (`exit 0`).

### Defaults
- **Cache Stampede Prevention:** Guard high-traffic cache keys with singleflight request coalescing, distributed mutex on cache-miss, or probabilistic early recomputation (XFetch) to prevent downstream database collapse when a key expires.
- **Bounded In-Memory Stores:** All in-memory maps, caches, and buffers must enforce maximum item caps and TTL/LRU eviction to prevent out-of-memory (OOM) crashes under sustained load.
- **Visibility Timeout Buffer:** Set queue job visibility timeouts strictly greater than the maximum expected processing deadline + network timeout.
- **Bulkheading:** Partition critical workloads (e.g., public API traffic vs. background exports vs. internal webhooks) into dedicated connection pools, worker queues, or process pools.

### Decisions
- **Consistency vs. Availability under Partition:** Defined in `intent/<slug>/spec.md` and `docs/nfr.md`. Read-heavy caches may serve stale data with `stale-while-revalidate` during upstream degradation; financial and inventory mutations must fail closed.
- **Rate-Limiter Tiering:** Local token-bucket for fast in-process shedding; distributed Redis/edge rate-limiter for global quota enforcement.

### Exceptions
- Short-lived CLI commands with no long-running connections or background loops may omit full circuit breaking, but must retain explicit timeouts.
