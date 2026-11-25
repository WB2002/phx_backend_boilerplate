#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=lib/toolchain.sh
. "scripts/lib/toolchain.sh"
echo "== verify =="
scripts/verify.sh
echo "== integration =="
MIX_ENV=test mix test --only integration
echo "== property =="
MIX_ENV=test mix test --only property
echo "== contract =="
MIX_ENV=test mix test --only contract
echo "== app-security =="
./scripts/ci/run-semgrep.sh && ./scripts/ci/scan-long-base64-literals.sh
echo "== ratchet =="
scripts/ratchet.sh
