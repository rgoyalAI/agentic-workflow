---
name: quality-gate
description: Aggregates all quality signals from previous phases and produces a deterministic pass/fail verdict. Checks compilation, test pass, coverage threshold, security findings, code review findings, architecture findings, and E2E results.
---

# Quality Gate

## Purpose

Aggregate **all phase outputs** into a **single, explainable decision** for whether the change/story may proceed: **PASS** or **FAIL**, with a **prioritized fix list** on failure. This skill is intentionally **deterministic**: same inputs and rubric ⇒ same verdict.

## Algorithm / Operations

1. **Collect artifacts** (read if present; treat missing required artifacts as failure unless marked N/A for the story type):
   - `./context/test-results.json`
   - `./context/coverage.json`
   - Review findings: **CODE-x**, **ARCH-x**, **SEC-x** (from respective agents or static tools), normalized to `{ severity, id, message, path? }`.
   - `./context/e2e-results.json` (if E2E applicable)
   - Build/compile outcome (from CI log or explicit `build-result.json` if your pipeline emits one)

2. **Apply rubric**

   **REQUIRED (blocking)**

   - **Code compiles / build succeeds** for affected targets.
   - **All automated tests pass** per `test-results.json` (`failed == 0`, `errors == 0` when tracked).
   - **Coverage**: `coverage.json.pass == true` (default threshold **80%** line; branch if enforced).
   - **Security**: no **Critical** or **Major** findings in `SEC-*` (definitions must match `ReviewSecurity` agent).
   - **Code review**: no **Critical** or **Major** `CODE-*` findings.
   - **Architecture review**: no **Critical** or **Major** `ARCH-*` findings.
   - **E2E**: if feature flagged as UI/API E2E in scope, `e2e-results.json` shows **zero failures** (skipped tests do not auto-pass unless justified and documented).

   **ADVISORY (non-blocking warnings)**

   - **Documentation updated** when public behavior changed (warn if not).
   - **Deployment artifacts present** when release expected (warn if not).

3. **Compute verdict**
   - **FAIL** if any REQUIRED check fails.
   - **PASS** only when all REQUIRED checks succeed; ADVISORY items may still list warnings.

4. **On FAIL**, emit **prioritized fix list**:
   - Order: security → correctness/build/tests → coverage → architecture → code style/maintainability → E2E
   - Each item: id, owner hint (agent/tool), suggested next action.

5. **Write** `./context/quality-gate-report.md` (human-readable, gate-ready).

## Input

- Paths above; mapping tables for severity names; whether E2E is in scope for this story.

## Output

**`./context/quality-gate-report.md`** containing:

- Per-gate table: Check | Status | Evidence file | Notes
- **Overall verdict**: `PASS` or `FAIL`
- **Fix list** (only if failing, prioritized)
- **Advisory** section for non-blocking items

Optional machine-readable mirror: `./context/quality-gate.json` if orchestrator requires parsing.

## Safety

- Do not **override** a failing test or security finding with subjective judgment—escalate to human waiver outside this skill.
- **Secrets**: redact tokens from any excerpts in the report.
- Clearly distinguish **“tool missing”** from **“check failed”** (e.g., no coverage file = fail or `missing-data` per pipeline policy—be explicit).
- Version the rubric in the report footer (`rubric_version: 1`) so audits can understand changes over time.
