# Quality Gate Report

## Metadata

| Field | Value |
|-------|-------|
| **Story ID** | `{{story_id}}` |
| **Run ID / correlation** | `{{correlation_id}}` |
| **Timestamp (UTC)** | `{{timestamp_utc}}` |
| **Branch / commit** | `{{git_ref}}` |

## Overall verdict

**Verdict:** `PASS` | `FAIL`

**Summary (one paragraph):**  
{{overall_summary}}

---

## Per-gate results

| Gate | Status | Evidence / artifact | Notes |
|------|--------|---------------------|-------|
| **Compile / build** | PASS / FAIL / SKIPPED | path or log | |
| **Unit tests** | PASS / FAIL / SKIPPED | path or log | |
| **Coverage** | PASS / FAIL / SKIPPED | path or log | threshold: {{coverage_threshold}} |
| **Security (SAST/SCA)** | PASS / FAIL / SKIPPED | path or log | |
| **Code review** | PASS / FAIL / N/A | PR link / reviewer | |
| **Architecture review** | PASS / FAIL / N/A | ADR / reviewer | |
| **E2E** | PASS / FAIL / SKIPPED | path or log | |
| **Documentation** | PASS / FAIL / N/A | paths updated | |

---

## Findings summary

### Blocking (must fix before merge)

{{blocking_findings}}

### Advisory (non-blocking)

{{advisory_findings}}

---

## Fix list (required when verdict is FAIL)

| # | Gate | Issue | Suggested fix | Owner |
|---|------|-------|---------------|-------|
| 1 | | | | |
| 2 | | | | |

---

## Sign-off

- **Quality gate runner:** {{agent_or_pipeline}}
- **Next action:** {{next_action}}
