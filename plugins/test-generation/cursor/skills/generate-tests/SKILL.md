---
name: generate-tests
description: Generates deterministic unit/integration tests aligned to repo patterns. Always follow AGENTS.md.
---

## When to use
- Before/after implementing a change to validate behavior.
- When updating APIs, database logic, or security-sensitive code paths.

## Instructions
1. Load `AGENTS.md` first and follow its deterministic context-loading protocol.
2. Detect existing test framework patterns (e.g., JUnit/PyTest/NUnit/etc.) from the repo.
3. Prefer table-driven tests and deterministic fixtures.
4. Include:
   - Happy path coverage
   - Negative/edge cases
   - Authorization and validation boundaries (when relevant)
5. If you cannot verify expected behavior from available repo context, report `missing-data`.

