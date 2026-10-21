---
name: add-dependency
description: Justify a dependency, check the registry, and install only after approval
disable-model-invocation: true
---
1. If `docs/adr/0001-stack.md` is missing or its Status is not `accepted`, stop
   and tell me. Do not guess a package manager.
2. Justify the need. Check whether existing dependencies or the standard library
   already cover it.
3. Verify the package exists in the registry under that exact name. Report
   publisher, last release date, popularity, license, known advisories, and
   transitive size.
4. Present that as a short table and ask me to approve.
5. Only after approval, install with the package manager command. Never
   hand-edit a manifest or lockfile.
6. If the dependency is significant, run `/record-decision`.
