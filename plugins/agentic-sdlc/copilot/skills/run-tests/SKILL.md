---
name: run-tests
description: Runs the correct test command for the detected stack and writes ./context/test-results.json with pass/fail aggregates. Use after tests exist or after test-generator.
---

## When to use

- Execute automated tests and persist **`./context/test-results.json`** (or `./context/{story-id}/test-results.json`) for orchestration and **quality-gate**.

## Preconditions

- Language/framework from `./context/language-profile.json` or repo signals (`pom.xml`, `package.json`, `*.csproj`, `go.mod`, …). If absent, detect from build files or return **`missing-data`**.

## Command map

| Stack | Default command |
|--------|------------------|
| Maven | `mvn -B -q test` (add `-pl` if scoped) |
| Gradle | `./gradlew test` (Windows: `gradlew.bat test`) |
| pytest | `pytest -q` or `uv run pytest` |
| .NET | `dotnet test` |
| Go | `go test ./...` |
| npm | `npm test` / `pnpm test` / `yarn test` (non-interactive / `ci` when defined) |

Override only with documented Makefile or project convention.

## Execution

Run from repo root or orchestrator `package_path`. Capture stdout/stderr; parse JUnit/pytest/dotnet summaries when possible. Record wall-clock **duration_ms** and **exit_code**.

## Output

**`test-results.json`**: `story_id`, `timestamp_utc`, `command` (argv array), `exit_code`, `duration_ms`, `summary` (passed/failed/skipped), `failures[]` with `test_name`, `file`, `line`, `message`; optional `raw_log_path`, `parse_status`.

## Safety

No secrets on CLI. Avoid destructive test modes unless the environment is disposable. Cap embedded log size in JSON.

## Handoff

**A2A** from `AGENTS.md`: `artifacts` include results path; `acceptance_criteria`: non-zero exit recorded, structured counts when parseable.
