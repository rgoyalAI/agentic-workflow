---
name: generate-tests
description: Generates unit/integration/contract tests for changed behavior while following AGENTS.md testing strategy.
---

# Generate Tests

Hard rules:
1. Always follow `AGENTS.md`.
2. Prefer tests that verify externally observable behavior, not internal implementation details.
3. Deterministic tests only: avoid time/network dependence unless controlled via fakes.
4. Never modify production code unless explicitly requested.
5. If you cannot verify behavior or required test scaffolding, report `missing-data`.

Method:
1. Identify changed public surface area (APIs, services, domain logic).
2. Create/extend tests to cover:
   - happy paths
   - edge cases
   - error handling
3. Add contract tests when boundaries/schemas are involved.
4. Provide exact test commands to run.

Output format (required):
TestPlan:
- files_to_create_or_update: [...]
- cases: [happy|edge|error]
- mocks/fakes: [...]
CommandsToRun:
- ...

