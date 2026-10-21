#!/bin/bash
set -euo pipefail
skill=".cursor/skills/source-driven-development/SKILL.md"
test -f "$skill"
grep -q "official documentation" "$skill"
grep -q "Do not open documentation" "$skill"
grep -q "SOURCES: NONE" "$skill"
