#!/bin/bash
set -euo pipefail
input=$(cat)
if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
  root=$(cd .. && pwd)
fi

f=$(echo "$input" | jq -r '.toolCall.args.TargetFile // .toolCall.args.file_path // .toolCall.args.path // .tool_input.file_path // .file_path // empty')

TEST_PATTERN='(^|/)(tests?|__tests__|itest)/|\.(test|spec)\.[a-z]+$|_test\.[a-z]+$|(^|/)test_[^/]*\.py$'

if { [ -f "$root/.cursor/.fix-mode" ] || [ -f "$root/.agents/.fix-mode" ]; } && echo "$f" | grep -Eq "$TEST_PATTERN"; then
  jq -n '{
    decision: "deny",
    reason: "Blocked: test files are frozen while .fix-mode exists. Fix the code, not the test. If the test itself is wrong, stop and ask the user."
  }'
  exit 0
fi

echo '{"decision":"allow"}'
