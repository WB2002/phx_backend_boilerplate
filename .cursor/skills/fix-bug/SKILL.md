---
name: fix-bug
description: Fix a bug test-first with the test files frozen during the fix
disable-model-invocation: true
---
1. Reproduce the bug as a failing test. Run it. Confirm it fails for the reason I expect.
2. Stop and ask me to commit that test.
3. Once I confirm, run `touch .cursor/.fix-mode`. This makes a hook block edits to test files.
4. Make the test pass by changing code only. If you believe the test itself is wrong, stop and ask me.
5. Run scripts/verify.sh and paste the output.
6. Always finish (or abort) with `rm -f .cursor/.fix-mode`.
