# Retry Loop and Rollback Protocol

This document describes **when** the SDLC pipeline retries work, **what** happens on each retry, **which phases re-run**, how **findings** are formatted for ImplementCode, **escalation** after repeated failure, and **rollback** using git.

---

## When retries trigger

A retry cycle is entered when any of the following occurs:

| Trigger | Typical cause | Route |
|---------|----------------|--------|
| **Review failure** | Cross-cutting check after ReviewCode / ReviewArchitecture / ReviewSecurity is Non-Compliant | Phase 3 |
| **Coverage below 80%** | ValidateCoverage does not meet threshold | Phase 3 with gap report |
| **E2E failure** | E2E suite fails in Phase 6a | Phase 3 with E2E-x findings |
| **Quality gate failure** | QualityGate aggregates FAIL (tests, coverage, reviews, security, or policy) | Phase 3 with prioritized fix list |

Phases **1 (Plan)** and **2 (Design)** are **not** re-run on retry; architecture and plan stay authoritative unless the human resets the story.

---

## What happens on each retry

1. **Increment** `retry_count` for the story (in `stories.json` / session state).  
2. **Append** a failure report to `./memory/stories/{story-id}/retry-{n}.md` (and mirror under `./context/{story-id}/` when configured).  
3. **Create a git tag** `retry-{story-id}-{n}` pointing at the current commit for **rollback**.  
4. **Route to ImplementCode (Phase 3)** with structured findings (see below).  
5. **Re-run Phases 3–7:** Implement → Review (×3) → Cross-cut → Test → E2E + Docs + Deploy → Quality Gate.  

Phase **8 (Complete)** runs only after a **PASS** quality gate.

---

## What re-runs vs what does not

| Re-run | Does not re-run |
|--------|------------------|
| Phases **3–7** (implement through QA gate) | Phase **1** PlanStory |
| New tests, reviews, coverage, E2E, docs, deploy as needed | Phase **2** DesignArchitecture |
| | |

---

## Retry findings format

Handoff to **ImplementCode** must include:

- **Specific findings** — numbered or tagged (e.g. `CODE-1`, `ARCH-2`, `SEC-1`, `COV-1`, `E2E-1`).  
- **File paths** — exact repository paths.  
- **Line numbers** — where applicable (reviews, static analysis, failing tests).  
- **Suggested fixes** — concrete, actionable edits (not generic advice).  

Example (illustrative):

```text
CODE-1: Missing negative test for expired JWT
  file: src/test/java/com/example/auth/AuthControllerTest.java
  line: 82
  suggestion: Add test case mocking clock past expiry; assert 401 on /auth/me

COV-1: Branch not covered in AuthService.refreshToken
  file: src/main/java/com/example/auth/AuthService.java
  lines: 45-52
  suggestion: Add unit test for refresh when refresh token is revoked
```

---

## Escalation after three retries

When `retry_count >= 3` and the quality gate still **FAIL**s (or a terminal policy says so):

1. **Pause** automation for that story.  
2. **Present to a human:** full history — `retry-1.md` … `retry-3.md`, `quality-gate-report.md`, latest `test-results.json`, and PR diff if any.  
3. **Human** decides: reset story, change scope, merge partial work, or override with documented risk.

---

## Rollback

- **Tags:** Each retry creates `retry-{story-id}-{n}` for a known-good rollback point.  
- **Manual rollback:** `git reset --hard retry-STORY-001-2` (example) to return the working tree to the tagged commit; **only** with team approval — this discards later commits on that branch.  
- **Use case:** Unrecoverable conflict, bad merge, or need to bisect before re-attempting Phase 3.

For CI integration of deterministic checks vs AI-augmented reviews, see `workflows/ci-integration.md`.

---

## Orchestrator responsibilities

On entering a retry, the orchestrator should:

- Persist the **incremented** `retry_count` before invoking ImplementCode so Phase 7 can enforce the three-retry cap.  
- Pass **only** the delta findings since the last pass when possible, to keep prompts small and avoid duplicate work.  
- Ensure **tags** are created before destructive edits so `retry-{story-id}-{n}` always points at a recoverable state.  

---

## Related documents

- `workflows/full-sdlc.md` — Full pipeline and phases 1–8  
- `workflows/story-lifecycle.md` — Example story walkthrough  
- `contexts/stories.json` — `retry_count` field on each story  
