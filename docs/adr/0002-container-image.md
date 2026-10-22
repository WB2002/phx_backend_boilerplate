# ADR 0002: Hardened Production Container Image
Status: accepted

## Context
The application needs to be packaged as a lightweight, secure container image for deployment on container orchestration platforms (e.g., AWS ECS/EKS, Kubernetes, Fly.io, Render). 
Elixir applications compile down to standalone OTP releases that bundle the Erlang Runtime System (ERTS) and application bytecode, requiring only the OS dynamic linker and basic shared libraries (libc, libstdc++, libncurses, openssl) at runtime.
Key operational and security requirements include:
1. Minimizing the container attack surface by excluding compilation tools, package managers, and development/AI metadata.
2. Operating under least-privilege principles (non-root UID, read-only root filesystem, dropped Linux capabilities).
3. Supporting horizontal scaling without mandatory clustering, while allowing cluster discovery when configured.
4. Ensuring deterministic, idempotent schema migrations prior to application launch.

## Decision
We will build a multi-stage `Dockerfile` and a deny-by-default `.dockerignore` with the following architectural choices:
1. **Base OS Distribution**:
   - Builder: `hexpm/elixir:1.20.0-erlang-27.0-debian-bookworm-20240904-slim` pinned by SHA-256 digest.
   - Runtime: `debian:bookworm-slim` pinned by SHA-256 digest.
2. **Deny-by-Default Build Context**:
   - Start `.dockerignore` with `*` and strictly re-include only required build sources (`mix.exs`, `mix.lock`, `config/`, `lib/`, `priv/`, `assets/`, `rel/`).
   - Explicitly exclude all `.md` files (including `README.md`, `AGENTS.md`), `.agents/`, `.cursor/`, `.github/`, `docs/`, `intent/`, `evals/`, `test/`, and `scripts/`.
3. **Execution Model & Hardening**:
   - Run as non-root user `10001:10001` with shell `/usr/sbin/nologin`.
   - Strip all setuid/setgid bits in the runtime layer.
   - Set `/app` ownership to `root:root` with write permissions revoked (`chmod -R go-w /app`) so the running process cannot modify its own code or release artifacts.
   - Configure `/tmp` as `RELEASE_TMP` and `HOME` to support `--read-only` root filesystems.
4. **Distribution & Cookie Security**:
   - Delete the build-time cookie file (`releases/COOKIE`) during release creation.
   - Require `RELEASE_COOKIE` to be supplied at runtime; the container exits with an error if it is missing.
   - Set `RELEASE_DISTRIBUTION=none` by default in `rel/env.sh.eex` unless `DNS_CLUSTER_QUERY` is explicitly configured.
5. **Database Migration Separation**:
   - Provide an explicit `/app/bin/migrate` entrypoint backed by `PhxBackendBoilerplate.Release.migrate/0` so migrations run as an isolated pre-start task or Kubernetes init-container.

## Alternatives considered
- **Alpine Linux**: Rejected due to `musl libc` known DNS resolution nuances and compatibility risks with C-based NIFs like `argon2_elixir`.
- **Google Distroless**: Rejected because standard Elixir release boot scripts (`bin/phx_backend_boilerplate`, `bin/server`) require POSIX `/bin/sh` to parse release configuration and environment flags.
- **Running `mix phx.server` directly in container**: Rejected because it requires the full Elixir compiler, Hex, Rebar, and source code in the production image, increasing image size by ~400MB and vastly increasing the attack surface.

## Consequences
- **Positive**:
  - Image size is minimized (~120MB uncompressed) with zero development or build tooling in runtime.
  - Development tools, documentation, tests, and AI configuration files are completely blocked from leaking into the container image.
  - Full compliance with read-only root filesystems and CIS Docker benchmark recommendations.
- **Negative / Trade-offs**:
  - Local file storage for uploads (`Storage.Local` pointing to `priv/uploads`) cannot write to the container filesystem when running with `--read-only`. Production deployments must configure `STORAGE_BACKEND=s3` or mount a persistent volume at the upload path.
  - Troubleshooting inside the container is intentionally limited because shell utilities like `curl`, `wget`, and package managers are absent.
