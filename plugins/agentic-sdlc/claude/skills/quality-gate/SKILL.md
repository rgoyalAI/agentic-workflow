---
name: quality-gate
description: Aggregates test results, coverage, reviews, E2E, and build signals into PASS/FAIL and quality-gate-report.md with prioritized fixes. Use as final gate before CompleteStory.
---

# Quality Gate (Claude Code)

## When to use

- **Single verdict** before story completion: combine artifacts from test, coverage, reviews, E2E, and build.

## Collect

- `./context/test-results.json`
- `./context/coverage.json`
- CODE-x, ARCH-x, SEC-x normalized `{ severity, id, message, path? }`
- `./context/e2e-results.json` if E2E in scope
- Build outcome (CI or local)

## Blocking (default)

- Build succeeds  
- Tests: no failures/errors when tracked  
- Coverage: `pass == true` or equivalent vs threshold  
- Security: no Critical/Major SEC-*  
- Code/Arch reviews: no Critical/Major  
- E2E: zero failures when in scope  

**Advisory:** documentation freshness, deployment artifacts—warn, do not block unless policy says so.

## Verdict

**FAIL** if any blocking check fails. **PASS** only when all blocking pass. On FAIL, **prioritized fix list**: security → build/tests → coverage → architecture → code → E2E.

## Output

**`./context/quality-gate-report.md`**: table per gate, overall verdict, fix list, advisory section, `rubric_version` in footer. Optional `quality-gate.json` if orchestrator parses.

## Rules

Do not waive failing tests or security with subjective judgment outside documented waiver. Distinguish **tool missing** from **check failed**.

## Handoff

A2A: `acceptance_criteria`: report matches rubric; no secrets in excerpts.
