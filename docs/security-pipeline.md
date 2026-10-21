# Language-Agnostic Security Scanning Pipeline

This document details the automated, language-agnostic security scanning pipeline implemented for the repository using GitHub Actions and open-source tools.

---

## 1. Pipeline Architecture & Scanning Capabilities

The pipeline integrates four complementary, free and open-source security tools into the repository's SDLC:

| Capability | Tool | Scope & Artifacts | Primary Triggers |
| :--- | :--- | :--- | :--- |
| **Dependency Alerts & Updates** | GitHub Dependabot | Package manifests (`mix.lock`, GHA workflows, future `package.json`, etc.) | Scheduled (Weekly) |
| **Software Composition Analysis (SCA)** | Trivy (`fs` mode) | Known CVEs in all supported lockfiles (`mix.lock`, etc.) | PR, Push, Schedule, Manual |
| **Misconfiguration & IaC** | Trivy (`fs` mode) | Docker Compose (`docker-compose.yml`), future Dockerfiles, Terraform, K8s | PR, Push, Schedule, Manual |
| **Static Application Security Testing (SAST)** | Semgrep OSS | Source code security flaws across Bash, YAML, JSON, JS/TS, Dockerfile, Elixir | PR, Push, Schedule, Manual |
| **Secret Detection** | Gitleaks | Unmasked credentials, tokens, and private keys in Git commits and PR diffs | PR, Push, Schedule, Manual |

---

## 2. GitHub Actions Workflow Configuration

The primary workflow is located at [`.github/workflows/security.yml`](file:///Users/axonitsolutions/Documents/personal/phx_backend_boilerplate/.github/workflows/security.yml).

### Triggers & Cadence

* **Pull Requests (`pull_request`)**: Evaluates code changes targeting `main` and `master`. Gitleaks scans commit diffs (`fetch-depth: 0`), while Trivy and Semgrep evaluate the working tree.
* **Pushes (`push`)**: Scans all commits pushed to default branches (`main`, `master`).
* **Scheduled (`schedule`)**: Runs every Monday at 04:00 UTC (`0 4 * * 1`) performing complete audits.
* **Manual (`workflow_dispatch`)**: Allows ad-hoc execution with customizable inputs:
  * `full_git_history` (boolean): When true, runs Gitleaks across the complete git commit history.
  * `fail_on_severity` (string): Configurable failure threshold for Trivy (default: `HIGH,CRITICAL`).

### Concurrency & Permissions

* **Concurrency**: Grouped per workflow and branch (`security-${{ github.workflow }}-${{ github.ref }}`) with `cancel-in-progress: true` to prevent redundant runner usage.
* **Minimal Permissions**: Workflows run with default read-only token permissions:
  ```yaml
  permissions:
    contents: read
    security-events: write # Required for Code Scanning SARIF upload
  ```
* **Pinned Dependencies**: All third-party GitHub Actions are pinned to verified full 40-character commit SHAs.

---

## 3. Tool Details & Baseline Triage Policy

### A. Secret Detection (Gitleaks)

* **Configuration**: Defined in [`.gitleaks.toml`](file:///Users/axonitsolutions/Documents/personal/phx_backend_boilerplate/.gitleaks.toml).
* **Local Pre-commit**: Also wired directly into `mix precommit` (`mix gitleaks`) and [`.githooks/pre-commit`](file:///Users/axonitsolutions/Documents/personal/phx_backend_boilerplate/.githooks/pre-commit).
* **Baseline / Allowlists**: Test credentials and mock tokens used strictly in documentation or demo controllers are scoped by path in `.gitleaks.toml`. Live keys or unmasked production secrets must never be added to allowlists.
* **Failure Policy**: Confirmed, un-allowlisted secret detections immediately fail CI. Secrets are redacted (`--redact`) in CI logs.

### B. Dependency & IaC Security (Trivy)

* **Configuration**: Uses [`.trivyignore`](file:///Users/axonitsolutions/Documents/personal/phx_backend_boilerplate/.trivyignore) for explicit vulnerability baselining.
* **Excluded Paths**: Skips generated or non-source directories (`--skip-dirs deps,_build,.git,tmp,priv/plts`).
* **Baselining Policy**:
  * Unpatched upstream transitive dependencies or accepted residual risks must be recorded in `.trivyignore` with:
    1. CVE identifier.
    2. Affected library and installed version.
    3. Rationale and compensating controls.
    4. Upstream tracking ticket or resolution plan.
    5. Expiration / review date.
  * *Current Baseline*: `CVE-2026-47071` (Hackney 1.25.0 timeout issue pinned transitively by `aws_encryption_sdk` 0.7; application code uses `:req` exclusively).
* **Failure Policy**: Any unsuppressed vulnerability or misconfiguration meeting or exceeding the threshold (`HIGH,CRITICAL`) fails CI (`exit-code: 1`).

### C. Static Application Security Testing (Semgrep)

* **Configuration**: Uses standard community open-source rules (`--config auto`, covering OWASP Top 10, CWE Top 25, and language-specific rules) running inside the official `semgrep/semgrep` Docker container.
* **Ignored Paths**: Excluded directories specified in [`.semgrepignore`](file:///Users/axonitsolutions/Documents/personal/phx_backend_boilerplate/.semgrepignore).
* **Failure Policy**: Any blocking high-confidence finding fails CI (`--error`).

### D. Automated Dependency Updates (Dependabot)

* **Configuration**: Defined in [`.github/dependabot.yml`](file:///Users/axonitsolutions/Documents/personal/phx_backend_boilerplate/.github/dependabot.yml).
* **Active Ecosystems**:
  * `hex` (Elixir package manager) checking `/`.
  * `github-actions` checking `/`.
* **Supply Chain Safeguard**: Both ecosystems configure `cooldown: default-days: 7` to guard against zero-day supply chain poisoning on immediate new releases.

---

## 4. Language & Ecosystem Extensibility Guide

The pipeline is inherently language- and framework-agnostic. No custom wrapper scripts or language-specific CI jobs are needed when new stacks are introduced.

### Adding a New Language / Package Manager

When introducing an additional package ecosystem (e.g. Node.js in `assets/`, Python for analytics, Go for a microservice, or Rust for NIFs):

1. **Lockfile**: Commit the package manager's standard lockfile (e.g., `package-lock.json`, `pnpm-lock.yaml`, `poetry.lock`, `go.sum`, `Cargo.lock`).
2. **Trivy Discovery**: Trivy automatically discovers and scans any supported lockfile without workflow edits.
3. **Semgrep Rules**: Semgrep's `--config auto` automatically activates the appropriate ruleset for the detected file extensions (`.js`, `.ts`, `.py`, `.go`, `.rs`).
4. **Dependabot Updates**: Add an entry to `.github/dependabot.yml`:
   ```yaml
   - package-ecosystem: "npm"
     directory: "/assets"
     schedule:
       interval: "weekly"
     cooldown:
       default-days: 7
   ```

### Adding Container & Infrastructure Files

* **Dockerfiles**: Trivy misconfiguration scanner and Semgrep Docker rules automatically scan `Dockerfile` and `Containerfile` as soon as they are committed.
* **Terraform / Kubernetes**: Trivy automatically analyzes `.tf`, Helm charts, and Kubernetes YAML for security misconfigurations.

---

## 5. Required GitHub Repository Settings

To maximize the benefits of this security scanning pipeline, repository administrators should ensure the following settings are enabled in GitHub:

1. **Code Security and Analysis** (`Settings > Code security and analysis`):
   * **Dependabot alerts**: Enabled.
   * **Dependabot security updates**: Enabled.
   * **Secret scanning**: Enabled (if repository is eligible).
   * **Push protection**: Enabled (prevents commits containing raw secrets from being pushed).
2. **Branch Protection Rules** (`Settings > Branches > Branch protection rules`):
   * Require status checks to pass before merging:
     * `Secret Detection (Gitleaks)`
     * `Dependency & IaC Security (Trivy)`
     * `SAST Static Analysis (Semgrep)`
