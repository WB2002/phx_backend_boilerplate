---
name: source-driven-development
description: Use when writing or changing a call to a framework, library, CLI, or runtime API, including when asked to skip the docs or code from memory.
---

# Source-driven development

## Overview

A library call is written only after the current official documentation is read. Memory and a deadline are not sources.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

- The change calls a framework, library, CLI, or runtime API.
- The user says you already know the API, or says not to open documentation.

Do not use this to delay reading the repository's own code.

## Required evidence

Before writing the call:

1. Read the current official documentation for that symbol.
2. Cite the page in the summary.
3. Mark any parameter you could not find as unverified and do not invent it.

Official means the project or runtime docs, not a blog, memory, or a guessed import path.

## Rationalizations

| Excuse | Reality |
| --- | --- |
| "You know this API. Do not open documentation." | Memory is not a source. Read the current official page and cite it before writing the call. |
| "Review is in 10 minutes." | An unverified call is not faster to repair during review. |

## Red flags

- `SOURCES: NONE`
- A snippet written from memory
- An import path that was not on the page you cited

All of these mean: delete the snippet and read the official page first.
