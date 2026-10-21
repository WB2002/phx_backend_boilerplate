#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== verify =="
scripts/verify.sh
echo "== integration/e2e =="
echo "TODO: configure integration/e2e — see docs/adr/0001-stack.md"
exit 1
echo "== ratchet =="
scripts/ratchet.sh
