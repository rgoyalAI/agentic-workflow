---
description: Generates deterministic unit/integration tests aligned to repo patterns. Always follow `AGENTS.md`.
---

## When to use
- Before/after implementing a change to validate behavior.
- When updating APIs, database logic, or security-sensitive code paths.

## Instructions
1. Follow the deterministic context-loading protocol from `AGENTS.md`.
2. Detect the repo's existing test framework and conventions.
3. Prefer deterministic, fixture-based, table-driven tests.
4. Cover happy path, negative path, and edge cases.
5. If you cannot verify expected behavior from repo context, report `missing-data`.

