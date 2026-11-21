# Repository Security Audit Report (`phx_backend_boilerplate`)

- **Audit Date:** 2026-11-21 (re-run against **uncommitted working tree**)
- **Scope:** Full repository (14 auditable units)
- **Artifacts:**
  - [coverage-ledger.json](coverage-ledger.json)
  - [findings.json](findings.json)

---

## 1. Executive Verdict

**`PASS`**

There is **1 confirmed Low** finding, **1 needs-validation Low** finding, and **14 rejected** candidates (including **9 prior High/Critical/Medium issues remediated in the current working tree**). There are **0 confirmed Critical, High, or Medium** findings.

---

## 2. Coverage Ledger Summary

- **Total Units Mapped:** 14 (`UNIT-001` through `UNIT-014`)
- **Total Units Audited:** 14 (**100% coverage**)
- **Threat Classes per Unit:** `SEC-AUTH`, `SEC-AUTHZ`, `SEC-INJ`, `SEC-EGRESS`, `SEC-SHARP`, `SEC-OPS`

See [coverage-ledger.json](coverage-ledger.json) for the full unit matrix.

---

## 3. Confirmed Findings (`SEC-AUD-NNN`)

### Low

#### `SEC-AUD-016`: Post-logout access JWT accepted when Redis deny-list write failed but read returns cache miss

- **Unit / CWE:** `UNIT-002` · `CWE-613` / OWASP A07:2021
- **Location:** [`expired_sessions.ex:56-58`](../../../lib/phx_backend_boilerplate/accounts/expired_sessions.ex#L56-L58), [`accounts.ex:113-119`](../../../lib/phx_backend_boilerplate/accounts.ex#L113-L119), [`accounts.ex:94-97`](../../../lib/phx_backend_boilerplate/accounts.ex#L94-L97)
- **Exploit Scenario:** Victim logs out (Postgres session deleted). If `ExpiredSessions.revoke/1` fails to write Redis but later `revoked?/1` returns `{:ok, nil}`, `authenticate_access_token/1` does not check Postgres and accepts the access JWT until `exp` (15 minutes). Requires an attacker to already possess the access JWT and a Redis write failure at logout; refresh is still blocked.
- **Disprover Proof:** Independent disprover gate confirmed the split-brain path; Postgres fallback applies only on Redis **read** errors, not on cache miss.
- **Remediation:** On `{:ok, nil}`, call `revoked_via_postgres?/1`, or always require an active `Session` row in `authenticate_access_token/1`.

---

## 4. Needs Validation (`NEEDS-VALIDATION`)

| ID | Unit | Severity | Location | Summary |
| :--- | :--- | :--- | :--- | :--- |
| `SEC-AUD-010` | `UNIT-002` | Low | [`auth_controller.ex:44-60`](../../../lib/phx_backend_boilerplate_web/controllers/auth_controller.ex#L44-L60) | `POST /api/auth/refresh` uses HttpOnly `SameSite=Lax` cookie only. Third-party CSRF is mitigated by Lax + CORS; **confirm** whether untrusted sibling subdomains share production eTLD+1 before requiring CSRF/Origin checks. |

---

## 5. Rejected Candidates Log

| ID | Prior Severity | Summary | Disproval / Remediation Reason |
| :--- | :--- | :--- | :--- |
| `SEC-AUD-001` | Critical | JWT `exp` not validated | **Remediated** — `validate_time_claims/1` in `tokens.ex` |
| `SEC-AUD-002` | High | Logout fail-open + live GraphQL WS | **Remediated** — disconnect broadcast + Redis-read Postgres fallback; residual → `SEC-AUD-016` |
| `SEC-AUD-003` | High | Leftmost `X-Forwarded-For` | **Remediated** — right-trust `client_ip.ex` |
| `SEC-AUD-004` | High | Stripe `payment_status` | **Remediated** — pending/completed mapping + async events |
| `SEC-AUD-005` | Medium | Refresh TOCTOU / email trim | **Remediated** — `FOR UPDATE` transaction + trimmed email |
| `SEC-AUD-006` | Medium | Rate limit Redis crash | **Remediated** — fail-open + telemetry |
| `SEC-AUD-007` | Medium | GraphQL body limit bypass | **Remediated** — path prefix + `CacheBodyReader` cap |
| `SEC-AUD-008` | Medium | ex_aws `"test"` in prod | **Remediated** — IAM-friendly prod config |
| `SEC-AUD-009` | Medium | CI security gaps | **Remediated** — Trivy `exit-code: 1`, pinned Semgrep, `ci.yml` permissions |
| `SEC-AUD-011` | Low | `x-user-id` rate limit header | Dead router path |
| `SEC-AUD-012` | Low | Static Stripe idempotency key | UX only |
| `SEC-AUD-013` | Low | `RequestLogger` in endpoint | Signed token required |
| `SEC-AUD-014` | Low | Demo file routes | `:demo_routes` off in prod |
| `SEC-AUD-015` | Low | Log redaction gaps | No exploitable leak found |

---

## 6. Threat Model Updates Required

[`docs/threat-model.md`](../../../docs/threat-model.md) in the working tree already documents JWT lifecycle, proxy spoofing, billing async payments, and GraphQL pre-auth limits. After merge, add:

1. **Redis deny-list split-brain:** Failed `revoke/1` write with successful `{:ok, nil}` read leaves access JWTs valid until `exp` despite Postgres session delete (`SEC-AUD-016`).

---

## 7. Note on Prior Report

An earlier artifact from the same calendar date listed **9 confirmed** findings against **committed** `main`. This re-audit evaluated the **current working tree**, where most of those issues are fixed but **uncommitted**. Re-run after merge to baseline CI and committed history.