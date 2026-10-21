#!/bin/bash
set -euo pipefail
skill=".cursor/skills/code-simplification/SKILL.md"
test -f "$skill"
grep -q "observable behavior" "$skill"
grep -q "A behavior change is acceptable" "$skill"
grep -q "200" "$skill"
grep -q "401" "$skill"
