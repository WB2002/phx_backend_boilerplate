#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck source=../lib/toolchain.sh
. "${ROOT_DIR}/scripts/lib/toolchain.sh"

CHANGED_FILES=()
while IFS= read -r file; do
  if [ -n "${file}" ]; then
    CHANGED_FILES+=("${file}")
  fi
done < <(./scripts/ci/changed-elixir-files.sh)

if [ "${#CHANGED_FILES[@]}" -eq 0 ]; then
  echo "mutation skipped: no eligible changed files"
  exit 0
fi

mkdir -p reports/mutation
REPORT_FILE="reports/mutation/mutation-report.txt"
: > "${REPORT_FILE}"

echo "Running mutation tests on changed files: ${CHANGED_FILES[*]}"
MIX_ENV=test elixir scripts/ci/mutate.exs "${CHANGED_FILES[@]}" | tee "${REPORT_FILE}"
