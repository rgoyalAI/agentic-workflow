---
name: validate-coverage
description: Validates coverage against threshold (default 80%) using JaCoCo, pytest-cov, go cover, Istanbul/nyc, lcov, or dotnet coverage. Writes coverage.json with verdict and gaps.
---

## When to use

- After tests run **with coverage enabled**, or to generate coverage via the stack-standard command and **fail** when below threshold.

## Steps

1. Load stack from `./context/language-profile.json` or repo detection.
2. Locate or produce coverage artifact (JaCoCo XML, `coverage-summary.json`, `coverage.xml`, `lcov.info`, Go `coverage.out`, Cobertura).
3. Parse aggregate **line** (and **branch** if policy requires).
4. Compare to `threshold_percent` (default **80**). Set `verdict: pass` only when metric ≥ threshold.
5. Write **`./context/coverage.json`**: `metric`, `threshold_percent`, `total_percent`, `verdict`, `files[]`, `source_report`, `gap_report` on fail.

## Output shape

Include `story_id`, `timestamp_utc`, totals, per-file breakdown (sorted paths), and `gap_report` with `below_threshold_files`, `hotspots`, **actionable** `recommendations` for implementer retry.

## Rules

Never fabricate percentages—on parse failure: `verdict: fail`, `error` reason, `missing-data`. Redact sensitive path segments if exporting outward. Honor tool excludes (JaCoCo, Istanbul) when comparing to CI.

## Integration with quality-gate

Feeds **quality-gate** directly; keep `verdict` boolean semantics aligned: **pass** iff `total_percent >= threshold_percent` for the stated `metric`.

## Handoff

**A2A** from `AGENTS.md`: `artifacts: ["./context/coverage.json"]`; `acceptance_criteria`: metric named, threshold explicit, `gap_report` present when failing.
