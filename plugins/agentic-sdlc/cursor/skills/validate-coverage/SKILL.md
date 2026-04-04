---
name: validate-coverage
description: Validates test coverage meets the minimum threshold (default 80%). Parses coverage reports from JaCoCo, pytest-cov, go cover, Istanbul/nyc, and dotnet coverage tools. Produces structured pass/fail verdict with per-file breakdown.
---

# Validate Coverage

## Purpose

Turn **coverage artifacts** into a **single deterministic verdict**: whether line (and when available branch) coverage meets a **minimum threshold** (default **80%**), with enough detail to fix gaps without re-running the entire suite blindly.

## Algorithm / Operations

1. **Load stack context** (language/framework) from `./context/language-profile.json` or prior detection.

2. **Ensure coverage data exists**
   - If the test run already produced coverage (e.g., `pytest --cov`, `ng test` with coverage), skip re-execution.
   - Otherwise run the **coverage command** for the stack (examples):
     - **Java / JaCoCo**: Maven/Gradle plugin producing `jacoco.xml` or site XML
     - **Python**: `pytest --cov` → `.coverage` / `coverage.json` / `coverage.xml`
     - **Go**: `go test -coverprofile=coverage.out ./...`
     - **JS/React/Angular**: Istanbul/nyc or CLI coverage output (`coverage/coverage-final.json`, `lcov.info`)
     - **.NET**: `dotnet test` with coverage collectors → `coverage.cobertura.xml` or tool-specific JSON

3. **Parse** the canonical report for the tool:
   - **JaCoCo XML**: aggregate line counters; branch counters when present
   - **coverage.json** (Istanbul/nyc/pytest-cov JSON): map to line %
   - **coverage.out** (Go): compute total covered statements vs total
   - **lcov.info**: sum `LF`/`LH` (and branch `BRF`/`BRH` if required)

4. **Compute**:
   - `total_line_coverage` (%)
   - `total_branch_coverage` (% or `null` if unavailable)

5. **Compare** to `threshold` (default **80%**). Set `pass` to `true` only if line coverage meets threshold **and** branch coverage meets threshold when branch gating is enabled for the pipeline.

6. **If failing**, generate **`gap_report`**:
   - Files lowest on coverage
   - Hotspots: functions/methods with zero coverage (when extractable)

## Input

- Coverage artifact path(s) or search roots (e.g., `target/site/jacoco/jacoco.xml`, `coverage/lcov.info`).
- `threshold` (default 0.8 as 80%).
- Optional: `branch_threshold`, `include_globs`, `exclude_globs`.

## Output

**`./context/coverage.json`**

```json
{
  "total_line_coverage": 0.0,
  "total_branch_coverage": null,
  "threshold": 0.8,
  "pass": false,
  "per_file": [
    { "path": "src/App.tsx", "line_pct": 72.1, "branch_pct": null }
  ],
  "gap_report": {
    "uncovered_files": ["..."],
    "uncovered_functions": [{ "file": "", "name": "" }]
  }
}
```

When passing, `gap_report` may be omitted or empty.

## Safety

- **Never** fabricate percentages—if parsing fails, set `pass` to `false`, record error reason, and list `missing-data`.
- Redact **paths** that expose usernames or internal-only directory names if publishing outward; workspace-local use may keep full paths.
- Large repos: cap `per_file` to top-N worst files plus summary stats to keep JSON bounded.
- Align threshold policy with org rules: default 80% is a **pipeline default**, not a universal law—make overrides explicit in session config.
