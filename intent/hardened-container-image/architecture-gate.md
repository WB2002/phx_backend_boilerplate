# Architecture gate: Hardened Production Container Image
Source: intent/hardened-container-image/spec.md
Status: accepted
Lifecycle: DRAFT
Recommendation: PASS

## Checklist
- Requirements complete: Yes. REQ-001 through REQ-005 cover build context hygiene, multi-stage compilation, non-root/read-only security, migration support, and automated verification.
- Architecture coherent: Yes. Uses standard Erlang/Elixir OTP releases packaged inside a multi-stage Docker container with clear separation of build-time and run-time dependencies.
- Boundaries reasonable: Yes. No application business logic is modified; container configuration is strictly decoupled via environment variables conforming to `config/runtime.exs`.
- Failure modes considered: Yes. Missing cookies cause deterministic failure; read-only filesystem prevents code injection; SIGTERM triggers clean shutdown.
- Data consistency correct: Yes. Database migrations are isolated to explicit `/app/bin/migrate` calls prior to application boot, preventing race conditions in rolling deployments.
- Scalability adequate: Yes. Container is stateless, runs without EPMD by default, and supports horizontal scaling behind cloud load balancers.
- Security considered: Yes. Full compliance with least privilege: non-root UID 10001, stripped setuid binaries, read-only code directory, no package managers or dev tools in runtime layer, build context stripped of secrets and AI/dev files.
- Observability defined: Yes. Existing `/health` and `/ready` probes integrate with container orchestrator liveness/readiness probes; telemetry and OTel propagate cleanly.
- Operational model defined: Yes. Run instructions, required environment variables, and rollback procedures are clearly documented.

## Recommendation
PASS. The design meets all tier 2 infrastructure criteria and enforces high security baselines. No blocking architectural gaps identified.
