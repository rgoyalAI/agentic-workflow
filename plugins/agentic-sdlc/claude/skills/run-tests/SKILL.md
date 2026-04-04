---
name: run-tests
description: Runs the correct test command for the detected stack and writes ./context/test-results.json with pass/fail aggregates. Use after tests exist or after test-generator.
---

# Run Tests (Claude Code)

## When to use

- Execute automated tests and persist **`./context/test-results.json`** (or story-scoped path) for orchestration and **quality-gate**.

## Preconditions

- Language/framework from `./context/language-profile.json` or repo signals; if absent, detect from build files or return **`missing-data`**.

## Command map

| Stack | Default command |
|--------|------------------|
| Maven | `mvn test` |
| Gradle | `./gradlew test` (Windows: `gradlew.bat test`) |
| pytest | `pytest` |
| Django | `python manage.py test` |
| .NET | `dotnet test` |
| Go | `go test ./...` |
| npm | `npm test` (CI mode non-interactive) |
| Angular | `ng test --no-watch --code-coverage` |

Override only with documented Makefile/project convention.

## Execution

Run from repo root or orchestrator `package_path`. Capture stdout/stderr; prefer JUnit XML / TRX / pytest summaries when parsing.

## Output

**`test-results.json`**: `total`, `passed`, `failed`, `skipped`, `errors`, `failures[]` with `name`, `message`, `file`, `line`; optional `raw_log_excerpt` truncated.

## Safety

No secrets on CLI. Avoid destructive test modes unless environment is disposable. Cap log volume in JSON.

## Handoff

A2A: `artifacts` include results path; `acceptance_criteria`: non-zero exit handled, structured counts when parseable.
