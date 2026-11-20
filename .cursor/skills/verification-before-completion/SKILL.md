---
name: verification-before-completion
description: Use before claiming any task, feature, bugfix, build, test, or check is complete, passing, or fixed to ensure fresh execution evidence precedes every completion claim.
---

# Verification Before Completion (Evidence Precedes Claims)

## Overview
Claiming work is complete without running the verification commands in the current turn and inspecting their raw output is a critical reliability failure. Confidence is not evidence. An earlier run before your last edit is not evidence.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use
- Before reporting any task (`TASK-NNN`), bug fix (`/fix-bug`), refactor, skill/doc change, or pre-PR check as complete.
- Before saying *"all tests pass"*, *"the build succeeds"*, *"the bug is fixed"*, or *"ready for review"*.

## The Gate Function: `IDENTIFY → RUN → READ → VERIFY → CLAIM`

1. **IDENTIFY:** Determine the exact deterministic verification commands required for the change:
   - Always run `scripts/verify.sh` as required by `AGENTS.md` (note: until `docs/adr/0001-stack.md` is accepted, `scripts/verify.sh` exits 1 at the configure-build TODO; run it, paste that exact output honestly, and never edit `scripts/verify.sh` without `.cursor/.guardrails-edit`).
   - When skills or docs change in this config repo, also run `scripts/check-skills.sh` and `scripts/check-docs.sh`.
   - When application tests, linters, typechecks, or eval checks apply, run the targeted test/check command.
2. **RUN:** Execute the full command(s) freshly **after** your final file edit.
3. **READ:** Inspect the complete stdout/stderr output and the process exit code.
4. **VERIFY:** Confirm the output actually proves the requirement (`REQ-NNN` / `UX-NNN`). If any check fails, fix the code (never weaken or delete the test) and re-run from Step 2.
5. **CLAIM:** Paste the raw command output and exit status in your response, and state accurately what passed and what remains blocked.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "I only made a tiny one-line edit after the tests passed." | One-line edits break syntax, imports, and assertions all the time. Re-run the verification command after the final edit. |
| "The code change is obviously correct; running the script takes extra time." | Unverified code is broken code waiting to be discovered by the user. |
| "`scripts/verify.sh` is a failing TODO stub right now, so I don't need to run it." | `AGENTS.md` mandates running `scripts/verify.sh` and pasting its output on every task. Run it and report the expected TODO exit 1 honestly. |

## Red Flags — STOP Immediately
- Saying "should pass now", "probably fixed", or "tests are green" without a fresh terminal command in the current turn
- Paraphrasing or summarizing command output instead of pasting the raw output block
- Editing or weakening a test or checker script just to produce a `0` exit code
