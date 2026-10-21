#!/bin/bash
input=$(cat)
f=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // empty')
TEST_PATTERN='(^|/)(tests?|__tests__|itest)/|\.(test|spec)\.[a-z]+$|_test\.[a-z]+$|(^|/)test_[^/]*\.py$'
if [ -f "${CURSOR_PROJECT_DIR:-.}/.cursor/.fix-mode" ] && echo "$f" | grep -Eq "$TEST_PATTERN"; then
  echo '{"permission":"deny","user_message":"Test files are frozen during a bug fix.","agent_message":"Blocked: test files are frozen while .cursor/.fix-mode exists. Fix the code, not the test. If the test itself is wrong, stop and ask the user."}'
  exit 2
fi
echo '{"permission":"allow"}'
