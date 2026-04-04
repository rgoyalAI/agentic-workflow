---
name: generate-tests
description: Generates unit/integration/contract tests for changed behavior while following AGENTS.md testing strategy.
disable-model-invocation: true
---

# Generate Tests

Hard rules:
1. Always follow `AGENTS.md`.
2. Prefer tests that verify externally observable behavior.
3. Deterministic tests only (avoid time/network unless controlled via fakes).
4. Do not modify production code unless explicitly requested.
5. If required evidence/tests cannot be created or run, output `missing-data`.

Procedure:
1. Identify public surfaces changed (APIs/services/domain logic).
2. Create/extend tests for happy paths, edge cases, and error handling.
3. Add contract tests when schema/boundaries exist.
4. Provide exact test commands to run and expected outcomes.

Output format (required):
TestPlan:
- files_to_create_or_update: [...]
- coverage_targets: [...]
- cases: happy|edge|error
CommandsToRun:
- ...

