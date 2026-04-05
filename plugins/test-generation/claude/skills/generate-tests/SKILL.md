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
6. **Database isolation**: **never use file-based databases** in async tests — use in-memory with shared connections (Python: `StaticPool`; Java: `H2 mem`; .NET: `DataSource=:memory:`). File-based embedded databases cause cross-connection isolation bugs. Always drop then recreate schema in setup before each test.
7. **Framework-controlled status codes**: use range checks for framework-generated responses (e.g., `assert status in (401, 403)` for missing auth); use exact assertions only for application-defined responses.
8. **Fixture resilience**: assert response status before extracting fields (e.g., check `resp.status_code == 201` before `resp.json()["id"]`) to prevent opaque `KeyError` cascades.

