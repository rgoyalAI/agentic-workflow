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
6. **Database isolation**: **never use file-based databases** in async tests — use in-memory with shared connections (Python: `StaticPool`; Java: `H2 mem`; .NET: `DataSource=:memory:`). File-based embedded databases cause cross-connection isolation bugs. Always drop then recreate schema in setup before each test.
7. **Framework-controlled status codes**: use range checks for framework-generated responses (e.g., `assert status in (401, 403)` for missing auth); exact assertions only for application-defined responses.
8. **Fixture resilience**: assert response status before extracting fields to prevent opaque `KeyError` cascades masking the real failure.

