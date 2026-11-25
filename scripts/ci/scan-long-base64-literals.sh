#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

MIN_LEN="${BASE64_LITERAL_MIN_LEN:-240}"
FOUND=0

scan_file() {
  local file="$1"
  if grep -nE "[A-Za-z0-9+/]{${MIN_LEN},}={0,2}" "${file}" >/dev/null 2>&1; then
    echo "suspicious long base64-like literal in ${file}" >&2
    grep -nE "[A-Za-z0-9+/]{${MIN_LEN},}={0,2}" "${file}" | head -5 >&2
    FOUND=1
  fi
}

while IFS= read -r -d '' file; do
  scan_file "${file}"
done < <(
  find lib config test scripts -type f \( -name '*.ex' -o -name '*.exs' -o -name '*.sh' \) \
    ! -path 'test/security/semgrep-fixtures/*' \
    ! -path 'test/fixtures/*' -print0 2>/dev/null || true
)

if [ "${FOUND}" -ne 0 ]; then
  echo "long-base64 scan failed (tune BASE64_LITERAL_MIN_LEN or allowlist if false positive)" >&2
  exit 1
fi

echo "long-base64 scan: ok"
