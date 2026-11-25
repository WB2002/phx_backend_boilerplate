#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

SEMGREP_SCOPE="${SEMGREP_SCOPE:-full}"
INCLUDE_ARGS=(
  --include 'lib/**/*.ex'
  --include 'lib/**/*.exs'
  --include 'config/**/*.exs'
  --include 'test/**/*.ex'
  --include 'test/**/*.exs'
  --include 'scripts/**/*.sh'
  --include 'scripts/**/*.bash'
)

TARGETS=()
if [ "${SEMGREP_SCOPE}" = 'changed' ]; then
  while IFS= read -r line; do
    [ -n "${line}" ] && TARGETS+=("${line}")
  done < <(./scripts/ci/changed-app-files.sh || true)
  if [ "${#TARGETS[@]}" -eq 0 ]; then
    echo "semgrep skipped: no changed app files"
    exit 0
  fi
else
  while IFS= read -r line; do
    [ -n "${line}" ] && TARGETS+=("${line}")
  done < <(
    find lib config test scripts -type f \( -name '*.ex' -o -name '*.exs' -o -name '*.sh' -o -name '*.bash' \) \
      ! -path 'test/security/semgrep-fixtures/*' \
      ! -path 'test/fixtures/*' -print 2>/dev/null || true
  )
fi

FILTERED=()
for f in "${TARGETS[@]}"; do
  case "${f}" in
    test/security/semgrep-fixtures/*|test/fixtures/*) continue ;;
    *) FILTERED+=("${f}") ;;
  esac
done
TARGETS=("${FILTERED[@]}")

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "semgrep skipped: no target files"
  exit 0
fi

OBFUSCATED_CONFIG="${ROOT_DIR}/semgrep/rules/obfuscated-exfil.yaml"
GUARDRAILS_CONFIG="${ROOT_DIR}/scripts/ci/semgrep-guardrails.yaml"

if command -v semgrep >/dev/null 2>&1; then
  semgrep scan --error \
    --config "${OBFUSCATED_CONFIG}" \
    --config "${GUARDRAILS_CONFIG}" \
    --config p/security-audit \
    "${INCLUDE_ARGS[@]}" "${TARGETS[@]}"
  exit 0
fi

if command -v docker >/dev/null 2>&1; then
  WORKDIR="$(mktemp -d /tmp/phx-semgrep-full.XXXXXX)"
  trap 'rm -rf "${WORKDIR}"' EXIT
  rsync -a --exclude '_build' --exclude 'deps' --exclude '.git' --exclude 'priv/plts' \
    "${ROOT_DIR}/" "${WORKDIR}/"
  docker run --rm -v "${WORKDIR}:/src" -w /src semgrep/semgrep:1.151.0 \
    semgrep scan --error \
    --config semgrep/rules/obfuscated-exfil.yaml \
    --config scripts/ci/semgrep-guardrails.yaml \
    --config p/security-audit \
    "${INCLUDE_ARGS[@]}" "${TARGETS[@]}"
  exit 0
fi

echo "semgrep: install semgrep CLI or Docker to run locally" >&2
exit 1
