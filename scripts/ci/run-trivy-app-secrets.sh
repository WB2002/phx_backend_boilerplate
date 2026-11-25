#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

SCAN_PATHS=(lib config priv scripts)
SKIP_DIRS="deps,_build,.git,tmp,priv/plts,.conformance-runner,reports"
TRIVY_ARGS=(
  fs
  --scanners secret
  --skip-dirs "${SKIP_DIRS}"
  --severity HIGH,CRITICAL
  --exit-code 1
)

if command -v trivy >/dev/null 2>&1; then
  for path in "${SCAN_PATHS[@]}"; do
    trivy "${TRIVY_ARGS[@]}" "${path}"
  done
  exit 0
fi

if command -v docker >/dev/null 2>&1; then
  WORKDIR="$(mktemp -d /tmp/phx-trivy-secrets.XXXXXX)"
  trap 'rm -rf "${WORKDIR}"' EXIT
  for path in "${SCAN_PATHS[@]}"; do
    rsync -a --exclude 'plts' "${ROOT_DIR}/${path}/" "${WORKDIR}/${path}/"
  done
  for path in "${SCAN_PATHS[@]}"; do
    docker run --rm -v "${WORKDIR}:/repo" aquasec/trivy:latest \
      fs --scanners secret --skip-dirs "${SKIP_DIRS}" \
      --severity HIGH,CRITICAL --exit-code 1 "/repo/${path}"
  done
  exit 0
fi

echo "trivy: install trivy CLI or Docker to run locally" >&2
exit 1
