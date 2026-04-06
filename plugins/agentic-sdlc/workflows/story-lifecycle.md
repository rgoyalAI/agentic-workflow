# Story Lifecycle Walkthrough

This document walks through **one story** end to end using a concrete example: **“Implement user authentication API with JWT.”** It matches the eight-phase pipeline and shows agents, context reads and writes, memory locations, git checkpoints, quality gate behavior, and completion steps.

---

## Example story (from `stories.json`)

- **id:** `STORY-001`  
- **jira_key:** `PROJ-1235`  
- **title:** Implement user authentication API  
- **description:** REST API for user authentication with JWT: login, registration, token refresh.  
- **requirement_refs:** `["CAP-001", "CAP-002", "CAP-003"]`  
- **language / framework:** `java` / `spring-boot`  

The orchestrator loads this story from `./context/stories.json` (or the project’s configured context root).

---

## Phase 1 — PLAN

| Aspect | Detail |
|--------|--------|
| **Agent** | PlanStory |
| **Reads** | Story entry in `stories.json`, repository layout, affected modules |
| **Produces** | `./memory/stories/STORY-001/plan.md` — tasks, file touch list, ordering |
| **Git** | Checkpoint: `chore(STORY-001): execution plan` |

**Sample `plan.md` (excerpt):** objectives, sub-tasks, and references to controllers, security config, and tests.

---

## Phase 2 — DESIGN

| Aspect | Detail |
|--------|--------|
| **Agent** | DesignArchitecture |
| **Reads** | `plan.md`, detect-language output, `languages/java/spring-boot.md`, relevant `standards/*.md` |
| **Produces** | `./memory/stories/STORY-001/architecture.md` — layers, JWT flow, package boundaries |
| **Git** | Checkpoint: `chore(STORY-001): architecture design` |

---

## Phase 3 — IMPLEMENT

| Aspect | Detail |
|--------|--------|
| **Agent** | ImplementCode |
| **Reads** | `plan.md`, `architecture.md`, acceptance criteria |
| **Produces** | Source and test code, `./memory/stories/STORY-001/implementation-log.md` |
| **Git** | Incremental commits; then `feat(STORY-001): implementation complete` |

**`implementation-log.md`** summarizes what was built, files changed, and how acceptance criteria map to tests.

---

## Phase 4 — REVIEW (parallel) + cross-cut

| Aspect | Detail |
|--------|--------|
| **Agents** | ReviewCode, ReviewArchitecture, ReviewSecurity **in parallel** |
| **Reads** | Shared Review Context Bundle: diff, story, build signals, `implementation-log.md` |
| **Produces** | CODE-x, ARCH-x, SEC-x findings; orchestrator runs **CrossCuttingCheck** → Compliant / Non-Compliant |
| **Git** | Optional review notes in memory; no merge until Phase 8 |

If **Non-Compliant**, the run routes to **retry** (see `retry-loop.md`) — back to ImplementCode with findings, **without** re-planning or re-architecting.

---

## Phase 5 — TEST

| Aspect | Detail |
|--------|--------|
| **Agents** | GenerateTests → RunTests → ValidateCoverage |
| **Reads** | `implementation-log.md`, acceptance criteria |
| **Produces** | `./context/STORY-001/test-results.json`, `./context/STORY-001/coverage.json` (see schema example under `plugins/agentic-sdlc/contexts/`) |

Example **`test-results.json` snippet** after a run:

```json
{
  "story_id": "STORY-001",
  "summary": { "total": 15, "passed": 14, "failed": 1, "skipped": 0, "error": 0 },
  "coverage": { "line_coverage_pct": 82.5, "threshold": 80, "pass": true }
}
```

If coverage &lt; 80% or tests fail, the orchestrator retries from Phase 3 with a gap or failure report.

---

## Phase 6 — E2E + DOCS + DEPLOY (three tracks)

| Track | Agents | Reads | Writes |
|-------|--------|-------|--------|
| **A** | GenerateE2E → RunTests(E2E) | AC, UI touchpoints | E2E results for QA |
| **B** | UpdateDocumentation → GitCheckpoint | Story + implementation log | README / CHANGELOG / ADR |
| **C** | GenerateDeployment → GitCheckpoint | Language, framework, layout | Dockerfile, K8s/Helm, pipeline snippets |

All three tracks **complete** before Phase 7.

---

## Phase 7 — QUALITY GATE

| Aspect | Detail |
|--------|--------|
| **Agent** | QualityGate |
| **Reads** | Memory logs, `test-results.json`, `coverage.json`, E2E output, review summaries |
| **Produces** | `./context/STORY-001/quality-gate-report.md` — PASS or FAIL with reasons |

**Evaluation:** deterministic checks (coverage threshold, test pass) plus aggregated review and risk signals. On FAIL with `retry_count < 3`, route to Phase 3 with a prioritized list. On FAIL with `retry_count >= 3`, escalate to a human.

---

## Phase 8 — COMPLETE

| Aspect | Detail |
|--------|--------|
| **Agent** | CompleteStory |
| **Reads** | QA PASS, branch state, story metadata |
| **Produces** | Pushed branch, **draft PR** (title/body from story + summary), **Jira transition** (e.g. to In Review / Done per project rules) |

**Jira:** `PROJ-1235` updated; story status in `stories.json` moves to completed state in session tracking.

---

## Context and memory summary

| Location | Typical contents |
|----------|------------------|
| `./context/stories.json` | Full backlog contract; source metadata |
| `./context/sdlc-session.json` | Orchestrator progress, retries per story |
| `./context/{story-id}/` | `test-results.json`, `coverage.json`, `quality-gate-report.md`, `retry-{n}.md` |
| `./memory/stories/{story-id}/` | `plan.md`, `architecture.md`, `implementation-log.md`, `retry-{n}.md` |

Paths may be unified per project; follow the **manage-context** skill and **OrchestrateSDLC** agent for the repo you are running against.

---

## Git checkpoints created (typical)

1. `chore(STORY-001): execution plan`  
2. `chore(STORY-001): architecture design`  
3. `feat(STORY-001): implementation complete`  
4. `docs(STORY-001): docs` (track B)  
5. `infra(STORY-001): deploy` (track C)  

Retries add tags such as `retry-STORY-001-{n}` for rollback; see `retry-loop.md`.
