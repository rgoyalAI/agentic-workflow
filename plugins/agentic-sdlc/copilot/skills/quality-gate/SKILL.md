---
name: quality-gate
description: Aggregates test results, coverage, reviews, E2E, and build signals into PASS/FAIL and quality-gate-report.md with prioritized fixes. Use as final gate before CompleteStory.
---

## When to use

- **Single verdict** before story completion: combine artifacts from tests, coverage, reviews, E2E, and build.

## Collect

- `./context/{story-id}/test-results.json` or `./context/test-results.json`
- `./context/coverage.json`
- Code/architecture/security review findings normalized `{ severity, id, message, path? }`
- `./context/{story-id}/e2e-results.json` if E2E in scope
- Build outcome (CI or local compile step)

## Blocking vs advisory

**Blocking (default):** build succeeds; tests have no failures; coverage meets threshold (`verdict: pass` or equivalent); no Critical/Major in security or code/arch reviews; E2E passes when in scope.

**Advisory:** documentation freshness, deployment artifact presence—warn unless policy elevates to blocking.

## Verdict logic

**FAIL** if any blocking check fails. **PASS** only when all blocking pass. On FAIL, emit **prioritized fix list**: security → build/tests → coverage → architecture/code → E2E.

## Output

**`./context/quality-gate-report.md`**: verdict, summary table per gate, details, fix list on fail, advisory section, `report_version` / `rubric_version` in footer. Optional `quality-gate.json` if orchestrator parses.

## Rules

Do not waive failing tests or Critical/Major findings without documented orchestrator waiver. Distinguish **tool missing** from **check failed**. Use UTC timestamps; deterministic verdict from structured inputs.

## Handoff

**A2A** from `AGENTS.md`: `acceptance_criteria`: report matches rubric; no secrets in excerpts; fix list ordered on FAIL.
