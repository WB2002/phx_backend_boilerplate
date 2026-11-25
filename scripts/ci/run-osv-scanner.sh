#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

# Match high-severity gate (CVSS >= 7.0).
AUDIT_LEVEL="${OSV_AUDIT_LEVEL:-high}"
case "${AUDIT_LEVEL}" in
  critical) MIN_CVSS="9.0" ;;
  high) MIN_CVSS="7.0" ;;
  medium) MIN_CVSS="4.0" ;;
  low) MIN_CVSS="0.1" ;;
  *)
    echo "osv-scanner: unknown OSV_AUDIT_LEVEL=${AUDIT_LEVEL}" >&2
    exit 1
    ;;
esac

OUTPUT="${ROOT_DIR}/.osv-scan-output.json"
trap 'rm -f "${OUTPUT}"' EXIT

run_json_scan() {
  if command -v osv-scanner >/dev/null 2>&1; then
    osv-scanner scan source -L mix.lock -f json --output-file "${OUTPUT}" \
      >/dev/null 2>&1 || true
    return 0
  fi

  if command -v docker >/dev/null 2>&1; then
    WORKDIR="$(mktemp -d /tmp/phx-osv.XXXXXX)"
    cp "${ROOT_DIR}/mix.lock" "${WORKDIR}/mix.lock"
    if [ -f "${ROOT_DIR}/osv-scanner.toml" ]; then
      cp "${ROOT_DIR}/osv-scanner.toml" "${WORKDIR}/osv-scanner.toml"
    fi
    docker run --rm \
      -v "${WORKDIR}:/repo" \
      -w /repo \
      ghcr.io/google/osv-scanner-action:v2.7.0 \
      scan source -L mix.lock -f json --output-file /repo/.osv-scan-output.json \
      >/dev/null 2>&1 || true
    if [ -f "${WORKDIR}/.osv-scan-output.json" ]; then
      cp "${WORKDIR}/.osv-scan-output.json" "${OUTPUT}"
    fi
    rm -rf "${WORKDIR}"
    return 0
  fi

  echo "osv-scanner: install osv-scanner CLI (brew install osv-scanner) or Docker" >&2
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  echo "osv-scanner: jq required to apply audit-level=${AUDIT_LEVEL} (brew install jq)" >&2
  exit 1
fi

run_json_scan

if [ ! -s "${OUTPUT}" ]; then
  echo "osv-scanner: no scan output (empty ${OUTPUT})" >&2
  exit 1
fi

VULN_PKG_COUNT="$(
  jq '[.results[]?.packages[]?] | length' "${OUTPUT}" 2>/dev/null || echo 0
)"
echo "Scanned mix.lock (${VULN_PKG_COUNT} vulnerable package(s) in OSV report)"

FINDING_ROWS="$(
  jq -r '
    .results[]?.packages[]?
    | . as $pkg
    | .groups[]?
    | [
        (.ids[0] // "unknown"),
        (.max_severity // "?"),
        $pkg.package.ecosystem,
        $pkg.package.name,
        $pkg.package.version
      ]
    | @tsv
  ' "${OUTPUT}" 2>/dev/null || true
)"

if [ -n "${FINDING_ROWS}" ]; then
  echo ""
  echo "OSV findings (job fails only when CVSS >= ${MIN_CVSS}, audit-level=${AUDIT_LEVEL}):"
  printf '%s\n' "ID	MAX_CVSS	ECOSYSTEM	PACKAGE	VERSION"
  printf '%s\n' "${FINDING_ROWS}" | while IFS=$'\t' read -r id cvss eco pkg ver; do
    printf '%s\n' "${id}	${cvss}	${eco}	${pkg}	${ver}"
  done
else
  echo "osv-scanner: no vulnerabilities reported in lockfile"
fi

FAIL_COUNT="$(
  jq --arg min "${MIN_CVSS}" '
    [
      .results[]?.packages[]?.groups[]?
      | (.max_severity | tonumber?)
      | select(. != null and . >= ($min | tonumber))
    ] | length
  ' "${OUTPUT}"
)"

if [ "${FAIL_COUNT}" -gt 0 ]; then
  echo "osv-scanner: ${FAIL_COUNT} finding(s) with CVSS >= ${MIN_CVSS} (${AUDIT_LEVEL})" >&2
  exit 1
fi

echo "osv-scanner: ok (no findings at or above ${AUDIT_LEVEL})"
exit 0
