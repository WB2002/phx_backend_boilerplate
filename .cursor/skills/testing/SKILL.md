---
name: testing
description: Apply when writing or changing tests, or when implementing behavior that needs proof.
---
- Order is the spec, then a test that fails, then implementation, then refactor. Do not change the failing test to make it pass.
- Pick only the layers the requirement needs: unit, integration, contract, end-to-end, property, load, security, migration, failure-mode.
- A test that only mirrors the implementation is not proof. Assert the observable outcome in the spec.
