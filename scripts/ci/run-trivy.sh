#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

SKIP_DIRS="deps,_build,.git,tmp,priv/plts,.conformance-runner,reports"

if command -v trivy >/dev/null 2>&1; then
  exec trivy fs --scanners vuln --ignorefile "${ROOT_DIR}/.trivyignore" --skip-dirs "${SKIP_DIRS}" --severity HIGH,CRITICAL --exit-code 1 "${ROOT_DIR}"
fi

if command -v docker >/dev/null 2>&1; then
  WORKDIR="$(mktemp -d /tmp/phx-trivy.XXXXXX)"
  trap 'rm -rf "${WORKDIR}"' EXIT
  rsync -a --exclude '_build' --exclude 'deps' --exclude '.git' --exclude 'priv/plts' --exclude 'tmp' \
    "${ROOT_DIR}/" "${WORKDIR}/"
  docker run --rm \
    -v "${WORKDIR}:/repo" \
    aquasec/trivy:latest \
    fs --scanners vuln --ignorefile /repo/.trivyignore --skip-dirs "${SKIP_DIRS}" --severity HIGH,CRITICAL --exit-code 1 /repo
  exit $?
fi

echo "trivy: install trivy CLI or Docker to run locally" >&2
exit 1
