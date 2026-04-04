---
name: validate-coverage
description: Validates coverage against threshold (default 80%) using JaCoCo, pytest-cov, go cover, Istanbul/nyc, lcov, or dotnet coverage. Writes coverage.json with verdict and gaps.
---

# Validate Coverage (Claude Code)

## When to use

- After tests run with coverage enabled, or to generate coverage via stack-standard command and **fail** the gate when below threshold.

## Steps

1. Load stack from `./context/language-profile.json` or detection.
2. Locate or produce coverage artifact (JaCoCo XML, `coverage.json`, `lcov.info`, Go `coverage.out`, Cobertura).
3. Parse aggregate **line** (and **branch** if policy requires).
4. Compare to `threshold` (default **0.8**). Set `pass` only when metric meets policy.
5. Write **`./context/coverage.json`**: totals, `per_file` or top-N worst files, `gap_report` on fail.

## Output shape

Include `total_line_coverage`, `threshold`, `pass`, optional `total_branch_coverage`, `gap_report` with uncovered files and recommendations for **implementer** retry.

## Rules

Never fabricate percentages—on parse failure: `pass: false`, error reason, `missing-data`. Redact sensitive path segments if publishing outward.

## Integration

Feeds **quality-gate** directly; keep boolean semantics aligned with **`verdict`** or `pass` field used by gate agent.

## Handoff

A2A: `acceptance_criteria`: metric named, threshold explicit, gap_report present when failing.
