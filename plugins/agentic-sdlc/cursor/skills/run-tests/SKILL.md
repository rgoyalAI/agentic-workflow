---
name: run-tests
description: Executes test suites using framework-specific commands and captures structured results. Supports Maven, Gradle, pytest, Django test, dotnet test, go test, npm test, and ng test.
---

# Run Tests

## Purpose

Execute the **appropriate automated test command** for the detected language/framework, capture **structured pass/fail/skip statistics**, and persist machine-readable results for orchestration, quality gates, and retries—without relying on human parsing of console logs.

## Algorithm / Operations

1. **Load context**
   - Read language/framework from `./context/language-profile.json` or equivalent session state from `detect-language`.
   - If missing, run **detect-language** first or return `missing-data`.

2. **Select command** from the map below (override only with documented project convention, e.g., Makefile targets).

3. **Execute** tests in the workspace root (or the relevant monorepo package directory), capturing **stdout** and **stderr** with non-interactive flags where applicable.

4. **Parse** output using framework-native reporters when possible (JUnit XML, TRX, pytest summary, etc.). Fall back to robust line parsing only when necessary.

5. **Write** `./context/test-results.json` with aggregates and per-failure details.

### Pre-test compilation

Before running tests, ensure the project compiles. Use the appropriate build command:
- Java / Maven: `mvn compile test-compile` (then `mvn test`)
- Java / Gradle: `./gradlew compileJava compileTestJava` (then `./gradlew test`)
- .NET: `dotnet build` (then `dotnet test`)
- Go: `go build ./...` (then `go test ./...`)

If IDE auto-compilation produces class files with a different JDK version, run `mvn clean test` or `./gradlew clean test` to clear stale artifacts. Build-tool `clean` targets are safe—they only remove the `target/` or `build/` directory.

### Command map (deterministic defaults)

| Stack | Command |
|--------|---------|
| Java / Maven | `mvn clean test` (prefer clean to avoid stale class files) |
| Java / Gradle | `./gradlew clean test` (Windows: `gradlew.bat clean test`) |
| Python (pytest) | `pytest` |
| Python (Django) | `python manage.py test` |
| .NET | `dotnet test` |
| Go | `go test ./...` |
| React (npm) | `npm test` (ensure CI/non-interactive mode; often `CI=true` or `-- --watch=false`) |
| Angular | `ng test --no-watch --code-coverage` |

6. **Exit code**: treat non-zero as test run failed unless parser proves all tests passed (some tools misbehave—prefer structured reports).

## Input

- Resolved working directory for the package under test.
- Optional: extra args (e.g., filter expression, single project in solution).

## Output

**`./context/test-results.json`**

```json
{
  "total": 0,
  "passed": 0,
  "failed": 0,
  "skipped": 0,
  "errors": 0,
  "failures": [
    {
      "name": "test or suite name",
      "message": "short message",
      "file": "path",
      "line": 0
    }
  ],
  "raw_log_excerpt": "optional truncated"
}
```

Include `errors` to capture collection errors / harness failures distinct from assertion failures when the parser supports it.

## Safety

- **Do not** pass secrets on the command line; use env vars and masked CI variables.
- Avoid **destructive** test modes (e.g., tests that drop databases) unless the pipeline explicitly uses disposable environments—if unsure, stop and surface `missing-data` / human confirmation.
- Cap **log volume** stored in JSON (truncate with pointer to full log path) to prevent huge artifacts in `./context/`.
- On Windows, normalize path separators in `file` fields consistently.
