---
name: security-audit
description: Run a multi-phase adversarial security audit using Cloudflare's coverage-ledger and disprover workflow combined with Trail of Bits false-positive verification.
disable-model-invocation: true
---

# Multi-Phase Adversarial Security Audit (`/security-audit`)

Argument: optional intent slug (`<slug>`) or target directory/scope (defaults to repository-wide audit).

Read-only audit workflow. Do not modify application code, configuration, tests, or `docs/threat-model.md`.
**Core Rule (Cloudflare & Review Separation Invariant):** *The agent pass that discovers a vulnerability candidate is never the one that confirms it.*

## Output Directory
- If an intent `<slug>` is provided: write artifacts under `intent/<slug>/reports/security-audit/`.
- If auditing repository-wide: write artifacts under `docs/reports/<YYYY-MM-DD>-security-audit/`.

---

## Phase 1: Reconnaissance & Deterministic Coverage Ledger
1. Read `docs/architecture.md`, `docs/threat-model.md`, `.cursor/policies/security.yaml`, and (when scoped to an intent) `intent/<slug>/spec.md` and `intent/<slug>/plan.md`.
2. Enumerate every trust boundary, entry surface (HTTP routes, GraphQL/RPC handlers, webhooks, CLI entry points, background jobs, AI/MCP tool handlers), authentication/authorization middleware, and sensitive data sink.
3. Write `coverage-ledger.json` containing every auditable unit:
   ```json
   {
     "scope": "<slug or repo>",
     "units": [
       {
         "unit_id": "UNIT-001",
         "surface": "api-route | auth-boundary | data-access | worker | egress-ai | infra-ci",
         "files": ["path/to/file"],
         "trust_boundary": "public-to-app | tenant-to-tenant | app-to-db | app-to-external-api",
         "status": "pending",
         "checks_performed": []
       }
     ]
   }
   ```

## Phase 2: Coverage-Led Hunting & Coverage Critic
1. Audit every unit in `coverage-ledger.json` across six threat classes:
   - **AuthN, Session & Crypto (`SEC-AUTH`)**: Broken authentication, JWT/session flaws, weak hashing/encryption, timing side-channels.
   - **AuthZ & Multi-Tenant Isolation (`SEC-AUTHZ`)**: BOLA/IDOR, missing tenant scoping, privilege escalation, mass assignment.
   - **Injection & Deserialization (`SEC-INJ`)**: SQL/NoSQL/command/template injection, XSS, prototype pollution, unsafe deserialization, path traversal.
   - **Zero-Trust Egress, SSRF & AI/DLP (`SEC-EGRESS`)**: Unallowlisted outbound fetches, cloud metadata SSRF, unredacted PII/PHI/secrets sent to external LLMs/APIs, prompt-injection tool escalation.
   - **Insecure Defaults & Sharp Edges (`SEC-SHARP`)**: Fail-open error handlers, fallback secrets (`env || 'default'`), permissive CORS, missing rate limits or timeouts.
   - **Supply Chain, Secrets & CI/CD (`SEC-OPS`)**: Hardcoded credentials, sensitive data in logs, unpinned CI actions, over-privileged workflow tokens.
2. Update each inspected unit in `coverage-ledger.json` to `"status": "audited"` with `"checks_performed"`.
3. **Coverage Critic Check:** Verify 100% of ledger units have `"status": "audited"`. If any unit was skipped, audit it before proceeding.

## Phase 3: Adversarial Candidate Validation (The Disprover Gate)
For every candidate vulnerability discovered in Phase 2, execute an independent **Disprover & False-Positive Gate** (combining Cloudflare Phase 3 and Trail of Bits `fp-check`). When subagents are available, dispatch a fresh readonly subagent per candidate; otherwise execute an explicit adversarial disprover pass that attempts to **disprove** the finding by answering:
1. **Attacker Control & Reachability:** Can untrusted input actually reach the vulnerable sink, or is it dead code / internal-only?
2. **Existing Upstream Mitigations:** Does an upstream middleware, gateway, schema validator, ORM parameterization, type guard, or framework default already block the exploit path?
3. **Concrete Exploit Preconditions:** What exact HTTP request, payload, and privilege level are required?
4. Assign a strict verdict:
   - `confirmed`: Concrete reachability proved and no upstream control blocks the exploit.
   - `needs_validation`: Plausible risk depending on runtime/infrastructure configuration not visible in source.
   - `rejected`: Disproved (false positive or mitigated upstream).

## Phase 4: Structured Findings (`findings.json`)
Write all candidates (including `rejected` items for audit trail transparency) to `findings.json`:
```json
{
  "summary": { "confirmed": 0, "needs_validation": 0, "rejected": 0 },
  "findings": [
    {
      "id": "SEC-AUD-001",
      "unit_id": "UNIT-001",
      "title": "<short title>",
      "severity": "Critical | High | Medium | Low",
      "cwe_owasp": "<CWE-NNN / OWASP category>",
      "location": "<file:line>",
      "verdict": "confirmed | needs_validation | rejected",
      "exploit_path": "<step-by-step attacker input to sink>",
      "disprover_notes": "<why disprover confirmed or rejected it>",
      "remediation": "<concrete fix specification for security-implementer>"
    }
  ]
}
```

## Phase 5: Independent Record Verification
Re-read every `file:line` cited in `findings.json` directly from disk to verify that the file path, line numbers, function names, and quoted code match the repository verbatim. Remove or correct any inaccurate citation.

## Phase 6: Target-Neutral Audit Report
Write `security-audit-report.md` in the output directory summarizing:
1. **Executive Verdict:** `PASS` (0 confirmed Critical/High/Medium findings) or `FAIL (ACTION REQUIRED)`.
2. **Coverage Ledger Summary:** Total units mapped vs. audited (must be 100%).
3. **Confirmed Findings (`SEC-AUD-NNN`):** Ordered by severity with verified `file:line`, exploit scenario, disprover proof, and remediation specification for `security-implementer`.
4. **Needs Validation (`NEEDS-VALIDATION`):** Runtime/environment assumptions requiring human owner confirmation.
5. **Rejected Candidates Log:** Brief table of disproved findings so reviewers know they were checked and ruled out.
6. **Threat Model Updates Required:** Any new entry points or abuse cases missing from `docs/threat-model.md`.

Stop after presenting the report path and summary. Do not modify application code and do not set any artifact `Status` to `accepted`.
