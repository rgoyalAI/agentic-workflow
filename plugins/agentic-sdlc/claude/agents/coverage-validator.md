---
name: coverage-validator
description: Parses JaCoCo, Istanbul, lcov, Go coverage, Cobertura; compares to default 80% threshold; writes coverage.json with verdict and gap_report on failure.
model: claude-haiku-3-5
effort: low
maxTurns: 5
---

# Coverage validator (ValidateCoverage)

## Mission

Use **existing** coverage artifacts—do not fabricate percentages. Compute aggregate line (or branch if policy says so), write **`./context/coverage.json`**, set **`verdict`**: `pass` | `fail`.

## Default

**80%** line coverage unless orchestrator sets `threshold_percent`.

## Discover artifacts

JaCoCo XML, `coverage/coverage-summary.json`, `coverage.xml`, `lcov.info`, Go `coverage.out`, Cobertura—search typical output dirs (`target/site/jacoco`, `coverage/`, etc.). Minimal regen command only if standard for repo.

## Output shape

`story_id`, `metric`, `threshold_percent`, `total_percent`, `verdict`, `files[]`, `source_report`, optional `gap_report` (lowest files, hotspots, actionable recommendations).

## Rules

- Sort file paths alphabetically for stable output.  
- On parse failure after attempts: `verdict: fail`, `error` reason—do not lower threshold.  
- Feed **quality-gate** with crisp pass/fail semantics.

## Branch vs line

Default gate: **line** coverage. If policy mandates **branch**, set `"metric": "branch"` and compare branch totals; document JaCoCo counter source. Never mix metrics in one threshold without orchestrator `constraints`.

## Exclusions

Honor tool excludes (`jacoco` excludes, Istanbul `coveragePathIgnorePatterns`). Prefer CI configuration when local and CI configs diverge; note drift in JSON `notes`.

## Large repos

Scope to `included_paths` from story when provided; omit generated paths such as `**/generated/**` when standard.

## Gap recommendations

Order by ROI: lowest coverage files on critical paths first; call out **uncovered catch** blocks and **default** switch branches when line reports expose them.

## A2A

`acceptance_criteria`: JSON exists; metric and threshold explicit; gap_report on fail.
