#!/bin/bash
set -euo pipefail
input=$(cat)

cmd=$(echo "$input" | jq -r '.toolCall.args.CommandLine // .command // empty')

ask() {
  jq -n '{
    decision: "ask",
    reason: "Package install: explicit human approval required. This command adds a package. Use /add-dependency and wait for the human to approve."
  }'
  exit 0
}

if echo "$cmd" | grep -Eq '(^|[[:space:];|&(])(npm|pnpm|yarn|bun|uv|poetry|cargo)[[:space:]]+add([[:space:]]|$)'; then
  ask
fi
if echo "$cmd" | grep -Eq '(^|[[:space:];|&(])go[[:space:]]+get([[:space:]]|$)'; then
  ask
fi
if echo "$cmd" | grep -Eq '(^|[[:space:];|&(])gem[[:space:]]+install([[:space:]]|$)'; then
  ask
fi
if echo "$cmd" | grep -Eq '(^|[[:space:];|&(])composer[[:space:]]+require([[:space:]]|$)'; then
  ask
fi
if echo "$cmd" | grep -Eq '(^|[[:space:];|&(])(npm|pnpm|yarn|bun)[[:space:]]+install[[:space:]]+[^[:space:]-]'; then
  ask
fi
if echo "$cmd" | grep -Eq '(^|[[:space:];|&(])pip[0-9]*[[:space:]]+install[[:space:]]+'; then
  if ! echo "$cmd" | grep -Eq 'pip[0-9]*[[:space:]]+install[[:space:]]+-r[[:space:]]+[^[:space:]]+[[:space:]]*$' \
    && ! echo "$cmd" | grep -Eq 'pip[0-9]*[[:space:]]+install[[:space:]]*$'; then
    ask
  fi
fi

echo '{"decision":"allow"}'
