#!/bin/bash
set -euo pipefail
input=$(cat)

cmd=$(echo "$input" | jq -r '.toolCall.args.CommandLine // .command // empty')

if echo "$cmd" | grep -Eiq '(deploy|release|apply|upgrade|publish).*(prod|production)|(prod|production).*(deploy|release|apply|upgrade|publish)'; then
  jq -n '{
    decision: "ask",
    reason: "Production change: explicit human approval required. This looks like a production deploy. Wait for the human to approve."
  }'
  exit 0
fi

echo '{"decision":"allow"}'
