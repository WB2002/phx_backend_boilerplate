---
name: dependency-policy
description: Apply when adding, upgrading, or removing a dependency.
---
- Add or upgrade a dependency only through `/add-dependency`. Never hand-edit a manifest or lockfile.
- Do not add a wrapper around a library the standard library or an existing dependency already covers.
- Say in the summary which dependency check you applied.
