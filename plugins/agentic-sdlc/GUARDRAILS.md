# GUARDRAILS -- Safety Protocol for Agentic SDLC

This document defines a **persistent safety protocol** for agent-driven software delivery. Guardrails survive across sessions: they are written down, versioned, and enforced by hooks plus human process.

## Signs Architecture

Each guardrail is a **sign** (a durable rule) with four fields:

| Field | Meaning |
|--------|---------|
| **Trigger** | The error, pattern, or risky context that activates the guardrail |
| **Instruction** | A deterministic command to the agent or tooling to prevent harm |
| **Reason** | Why this guardrail exists (blast radius, compliance, trust) |
| **Provenance** | When and how the sign was added (phase, review, incident ID) |

Agents and hooks evaluate triggers; instructions must be unambiguous. Provenance makes audits and rollbacks possible.

---

## Sign 1 — No force-push on protected integration branches

| Field | Content |
|--------|---------|
| **Trigger** | Force push detected (`git push --force`, `git push -f`) targeting `main` or `develop` (or configured protected branches). |
| **Instruction** | **NEVER** run `git push --force` on `main`/`develop`. Use revert commits, repair branches, or coordinated history fixes with release management. |
| **Reason** | Force-pushing shared history destroys collaborators’ bases, breaks CI, and hides audit trails. |
| **Provenance** | Phase H — Guardrails framework (initial catalog). |

---

## Sign 2 — Production DDL requires human approval

| **Trigger** | DDL or destructive SQL detected for production targets (e.g. `CREATE/ALTER/DROP`, `TRUNCATE`, broad `DELETE`/`UPDATE`). |
| **Instruction** | **ALWAYS** require explicit human approval before executing database DDL in production; use change windows and rollback plans. |
| **Reason** | Schema mistakes cause outages and data loss; automation must not bypass CAB or DBA policy. |
| **Provenance** | Phase H — Guardrails framework (initial catalog). |

---

## Sign 3 — Retry ceiling per story

| **Trigger** | Automated retry counter for the current story **≥ 3** (failures or blocked fix attempts, as recorded in session state). |
| **Instruction** | **STOP** the retry loop and **escalate to a human** with logs, last error, and story id. Do not spin indefinitely. |
| **Reason** | Runaway loops waste tokens, mask root causes, and can amplify partial damage. |
| **Provenance** | Phase H — Guardrails framework (initial catalog). |

---

## Sign 4 — No secrets in version control

| **Trigger** | Secret-like patterns detected in staged or committed files (API keys, tokens, private keys, connection strings with credentials). |
| **Instruction** | **NEVER** commit secrets, API keys, or tokens. Rotate if exposed; use secret managers and env injection. |
| **Reason** | Secrets in VCS are effectively public; scanning is reactive, prevention is mandatory. |
| **Provenance** | Phase H — Guardrails framework (initial catalog). |

---

## Sign 5 — No deleting branches with unmerged work (without approval)

| **Trigger** | Branch delete requested while remote/local history shows **unmerged** commits relative to the integration target. |
| **Instruction** | **NEVER** delete such branches without explicit human approval and verification of backup/reflog. |
| **Reason** | Unmerged work loss is irreversible without recovery discipline. |
| **Provenance** | Phase H — Guardrails framework (initial catalog). |

---

## Sign 6 — Valid context files

| **Trigger** | Write or overwrite of a context file (e.g. JSON/YAML under agreed `context/` or plugin context paths). |
| **Instruction** | **ALWAYS** validate JSON/YAML syntax **before** persisting; fix structure before content debates. |
| **Reason** | Invalid context poisons downstream agents deterministically and is hard to debug under load. |
| **Provenance** | Phase H — Guardrails framework (initial catalog). |

---

## Sign 7 — Stay within story scope

| **Trigger** | Edit or tool action touching files **outside** the approved story file list / scope boundary. |
| **Instruction** | **NEVER** modify files outside the current story scope during implementation; expand scope only via explicit human/plan update. |
| **Reason** | Scope creep breaks reviewability, estimates, and ownership. |
| **Provenance** | Phase H — Guardrails framework (initial catalog). |

---

## Sign 8 — Token budget escalation

| **Trigger** | Cumulative session tokens **> 80%** of the allocated session budget (or phase budget). |
| **Instruction** | **STOP** autonomous expansion; summarize state, remaining work, and options; **escalate** for budget or model decision. |
| **Reason** | Prevents cost overruns and low-signal grinding; keeps humans in the loop for trade-offs. |
| **Provenance** | Phase H — Guardrails framework (initial catalog). |

---

## Calibrated Autonomy Model

Autonomy is tiered so routine work flows fast and risky work stays visible.

| Tier | Default behavior | Examples |
|------|------------------|----------|
| **Tier 1 — Auto-approve** | Proceed without extra human gate | Read files, load context, write non-production context files, run tests locally in sandbox |
| **Tier 2 — Log and proceed** | Emit structured log / trace; continue | Code edits on in-scope files, local `git commit`, branch creation, lint/format |
| **Tier 3 — Human approval** | Block until explicit approval | Open PR, `git push` to remotes, Jira/issue creation in prod trackers, DB migrations against shared/prod, destructive file delete |

Hooks map tool invocations to tiers; Tier 3 must not complete silently.

---

## Cost Controls

- **Token budget per phase**: Each SDLC phase gets a numeric token ceiling; agents report usage against it.
- **Model selection by task**: Cheap/fast models for retrieval and formatting; capable models for architecture and security-sensitive edits.
- **Session spending cap**: Hard stop when cumulative spend or tokens crosses the session cap (align with Sign 8).

Together, calibrated autonomy and cost controls keep agentic SDLC safe, auditable, and affordable.

---

## Enforcement surfaces

| Mechanism | Role |
|-----------|------|
| **This document (`GUARDRAILS.md`)** | Human-readable contract; onboarding and audits. |
| **Cursor hooks** (`cursor/hooks/*.ps1`) | Automated checks on tool use (block destructive commands, Tier 3 gates, retry limits). |
| **Session state** (`context/sdlc-session.json`) | Per-story `retry_count` and metadata for escalation (see rate-limit hook). |
| **Environment** | `AGENTIC_STORY_ID`, `AGENTIC_TIER3_APPROVED`, optional `AGENTIC_FORCE_RETRY_COUNT` for testing. |

Hooks are best-effort: they depend on stdin payloads and workspace paths. Agents must still follow signs when hooks cannot classify an edge case.

---

## Agent responsibilities (summary)

1. Validate JSON/YAML before context writes (Sign 6).
2. Classify Tier 1–3; obtain approval for Tier 3 and prod DDL (Sign 2, table above).
3. Escalate after repeated failures per story (Sign 3); do not loop blindly.
4. Stop and escalate past ~80% token budget (Sign 8).
5. Hooks are not a substitute for policy—follow signs even when unenforced.

---

## Review cadence

- **Each release train**: Re-read signs for new tools (MCP, CI, package managers).
- **After incidents**: Add or tighten a sign; record provenance (postmortem or ticket).
- **Quarterly**: Reconcile token budgets and Tier 3 list with org risk appetite.

## Quick reference — eight signs

| # | Headline |
|---|----------|
| 1 | No force-push on `main` / `develop`. |
| 2 | Human approval before prod DDL. |
| 3 | Escalate after 3 failures per story. |
| 4 | No secrets in VCS. |
| 5 | No unmerged branch delete without approval. |
| 6 | Validate JSON/YAML before context writes. |
| 7 | Stay within story file scope. |
| 8 | Escalate past ~80% session token budget. |

Does not replace full sign definitions above.
