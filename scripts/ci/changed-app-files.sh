#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

BASE_REF="${QUALITY_BASE_REF:-origin/main}"
if git rev-parse --verify "${BASE_REF}" >/dev/null 2>&1; then
  MERGE_BASE="$(git merge-base HEAD "${BASE_REF}" 2>/dev/null || echo "${BASE_REF}")"
else
  MERGE_BASE="HEAD~1"
fi

git diff --name-only --diff-filter=ACMRT "${MERGE_BASE}...HEAD" -- \
  'lib/**' 'test/**' 'config/**' 'scripts/**' \
  | while IFS= read -r file; do
      [ -n "${file}" ] && [ -f "${file}" ] && printf '%s\n' "${file}"
    done || true
