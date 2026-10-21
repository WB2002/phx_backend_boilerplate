# Threat Model

This document outlines the threat model for the Phoenix Backend Boilerplate application and its CI/CD security scanning pipeline.

---

## Assets

1. **Production & Environment Secrets**: API keys, AWS KMS keys, database credentials, JWT signing secrets (`SECRET_KEY_BASE`).
2. **Customer & Application Data**: User credentials (passwords hashed via Argon2), uploaded documents, database state in PostgreSQL.
3. **Application Availability & Integrity**: HTTP endpoint responsiveness, Oban background job execution, Nebulex caching layer, Telemetry and CloudWatch metrics.
4. **Source Code & Build Infrastructure**: GitHub Actions runners, build cache, deployment manifests, release artifacts.

---

## Entry Points

1. **Public Web Endpoints**: Phoenix router endpoints (REST API, Absinthe GraphQL API, Demo session endpoints).
2. **Background Job Queue**: Oban worker inputs from database queues and external events.
3. **Third-Party Service Webhooks & Callbacks**: Inbound webhooks, AWS S3 upload events, ClamAV scanning socket (`3310`).
4. **Developer & CI/CD Pipelines**: Git pushes, Pull Requests, GitHub Actions runner execution, pre-commit hooks.

---

## Trust Boundaries

1. **Client / Server Boundary**: Between external HTTP/GraphQL clients and Phoenix plug pipelines (`Guardian`/`Joken` auth, `CorsPlug`, input validators).
2. **Application / Database Boundary**: Between Phoenix application code and PostgreSQL via Ecto query builders and parameterized queries.
3. **Application / Third-Party Services**: Outbound HTTP requests made via `:req` to external APIs, AWS KMS, CloudWatch, and ClamAV.
4. **Developer Machine / Remote VCS**: Between local Git working trees and the remote GitHub repository.
5. **CI Runner / Target Artifacts**: Between GitHub Actions runners and deployed release environments.

---

## Abuse Cases

1. **Secret Leakage in Git History**: Developer or automation accidentally commits API credentials or private keys into public or shared VCS.
2. **Dependency Supply Chain Compromise**: Upstream Hex or GitHub Actions dependency publishes a malicious update or suffers a maintainer account takeover.
3. **Known Vulnerability Exploitation**: Publicly disclosed CVE in an application dependency is exploited before maintainers upgrade.
4. **Injection & Deserialization Attacks**: Unvalidated input passed into SQL, shell commands, or unsafe Erlang binary deserialization (`:erlang.binary_to_term/1`).
5. **Mutable GitHub Actions Tag Poisoning**: Third-party GitHub Action tag (e.g. `@v1`) is compromised and runs arbitrary code on the runner.
6. **Malicious File Uploads**: Uploading weaponized files bypassing file-type restrictions or malware scanners.

---

## Mitigations

| Threat / Abuse Case | Mitigation Mechanism | Verification / Enforcement |
| :--- | :--- | :--- |
| **Secret Leakage** | Pre-commit hook (`gitleaks protect`), CI secret scanning workflow (`gitleaks-action`), `.gitleaks.toml` config | `.githooks/pre-commit`, `mix precommit`, `.github/workflows/security.yml` |
| **Dependency Supply Chain** | Pinned lockfiles (`mix.lock`), Dependabot 7-day cooldown on new releases, pinned full commit SHAs on all GHA actions | `.github/dependabot.yml`, `.github/workflows/*.yml`, Semgrep rule `dependabot-missing-cooldown` |
| **Known Vulnerabilities (SCA)** | Trivy filesystem vulnerability scanner checking all lockfiles, explicit `.trivyignore` baseline for accepted risks | `.github/workflows/security.yml`, `.trivyignore` |
| **Injection & SAST Flaws** | Ecto parameterized queries, Phoenix HTML escaping, Semgrep SAST rule packs (`p/security-audit`, `p/owasp-top-ten`) | `.github/workflows/security.yml`, Credo checks, Dialyzer |
| **Mutable Action Tags** | Pinned 40-character commit SHAs for third-party GitHub Actions | Verified in `ci.yml` and `security.yml`, enforced by Semgrep rule `github-actions-mutable-action-tag` |
| **Malicious File Uploads** | Streaming upload to ClamAV daemon (`INSTREAM`), fail-closed validation | `PhxBackendBoilerplate.Storage.UploadScanner`, `docker-compose.yml` ClamAV service |
| **Residual Risk (Hackney)** | Hackney 1.25.0 timeout risk (`CVE-2026-47071`) baselined in `.trivyignore`; application code uses `:req` (Finch/Mint), not Hackney | Documented in `docs/security-pipeline.md` and `.trivyignore` |
