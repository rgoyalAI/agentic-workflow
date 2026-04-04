# Prompt Template: Quality Gate — Deterministic Rubric

Use this with the **QualityGate** agent or CI evaluation. Verdicts must be **evidence-based**; each gate references **artifacts** (logs, reports, URLs). Replace `{{placeholders}}`.

---

## Inputs

- **Story ID:** `{{story_id}}`
- **Change summary:** {{short_description}}
- **Artifacts directory:** {{paths_to_logs_reports}}
- **Policy version:** `{{policy_git_sha_or_tag}}`

---

## Rubric (deterministic)

Evaluate each gate **PASS**, **FAIL**, or **SKIPPED** (SKIPPED only with documented reason, e.g. not applicable).

### G1 — Compile / build

- **PASS:** Clean build for all affected projects; exit code 0.
- **FAIL:** Any compiler error or required build step failure.
- **Evidence:** `build.log` or CI job link.

### G2 — Unit tests

- **PASS:** All unit tests pass; no unapproved skips.
- **FAIL:** Any failure or crash.
- **Evidence:** JUnit XML / pytest report / TRX.

### G3 — Coverage

- **PASS:** Aggregate and per-package coverage ≥ **{{line_threshold}}%** (and branch ≥ **{{branch_threshold}}%** if policy applies).
- **FAIL:** Below threshold without waiver ticket **{{waiver_id}}**.
- **Evidence:** LCOV/Cobertura + `coverage-report.md`.

### G4 — Security (SAST/SCA)

- **PASS:** No **critical** findings; **high** findings either fixed or waived with expiry.
- **FAIL:** Unresolved critical; policy violation per security team.
- **Evidence:** SARIF summary or Snyk/Dependabot export.

### G5 — Code review

- **PASS:** Required approvals per branch policy; all comments resolved or tracked.
- **FAIL:** Missing approval; open blocking comments.
- **Evidence:** PR URL + review state (API or screenshot policy).

### G6 — Architecture review

- **PASS:** Required reviewer approved OR change classified **low risk** per rubric.
- **FAIL:** Missing mandatory arch review for high-risk change.
- **Evidence:** PR label, checklist, or ADR link.

### G7 — E2E

- **PASS:** Targeted E2E suite green for this story’s tag.
- **FAIL:** Any failure in scope without known infra issue ticket.
- **Evidence:** Playwright/Cypress report.

### G8 — Documentation

- **PASS:** README/runbook updated when behavior or ops steps changed; ADR if architecture changed.
- **FAIL:** Required docs missing per change classification.
- **Evidence:** File list in PR.

---

## Overall verdict

- **PASS:** All **non-skipped** gates **PASS**.
- **FAIL:** Any gate **FAIL** without approved waiver covering that gate.

---

## Waiver rules

- Waivers must include: **ID**, **owner**, **expiry date**, **risk acceptance**, **mitigation**.
- Waivers do **not** apply to **compile** or **security critical** unless CISO exception documented.

---

## Output format

Produce `quality-gate-report.md` using `templates/quality-gate-report.md` with:

- Per-gate table filled
- **Blocking** vs **advisory** findings
- **Fix list** if FAIL

---

## Chain-of-thought (visible)

Before final verdict, briefly state: evidence reviewed, gates failed (if any), waivers applied, correlation ID for logs.

---

## A2A envelope

- `acceptance_criteria`: verdict matches rubric; advisory vs blocking distinguished; fix list on FAIL; CoT before write
