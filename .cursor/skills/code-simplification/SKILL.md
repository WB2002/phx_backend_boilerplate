---
name: code-simplification
description: Use when code already works and a shorter or cleaner version is requested, including when a behavior change is offered as the cleanup.
---

# Code simplification

## Overview

Simplification preserves observable behavior exactly. A shorter function that returns a different result is a new requirement, not a cleanup.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

- Tests pass and the change is only to make working code easier to read.
- The user says a behavior change is acceptable if the code gets shorter.

Do not use this to implement a new requirement, and do not use it as a review of your own change. Hand the diff to the independent reviewers.

## Required result

The callers' observable results stay the same, including return type, status codes, errors, and side effects. If the requested edit changes any of those, stop and leave the code unchanged.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "A behavior change is acceptable." | Permission to change behavior starts a new requirement. It does not turn the change into cleanup. |
| "Preserves the existing success condition." | Callers that observe `200` and `401` do not observe `true` and `false`. The condition is not the contract. |

## Red flags

- A return type change labeled as a simplification
- Status codes replaced by a boolean
- Tests rewritten so the shorter code passes

All of these mean: restore the original behavior and stop.
