---
name: git-checkpoint
description: Creates git commits and tags at SDLC phase boundaries for rollback capability. Use after implementation, testing, documentation, and deployment phases to create recoverable checkpoints.
---

# Git Checkpoint

## Purpose

Git checkpoint operations for the Agentic SDLC workflow. Ensures every major phase can be **rolled back** to a known commit or tag without relying on unstaged editor state.

## Operations

### Phase checkpoint commit

- After a coherent unit of work (implementation, tests, docs, or deployment artifacts), create a **single logical commit** with staged changes only.
- Use the commit message conventions below so history is searchable by story id.

### Retry tag creation

- When entering a retry loop for a story, create an annotated or lightweight tag (per repo policy) at the current HEAD before applying fixes, using the tag pattern **`retry-{story-id}-{n}`** where `n` is the retry attempt number (1-based).

### Rollback to tag

- To discard failed work after a retry decision, reset or checkout to the appropriate **`retry-{story-id}-{n}`** tag or prior checkpoint commit **on the local branch**, then re-apply guided fixes from findings.
- Prefer branch-local recovery; do not rewrite shared history.

## Commit message conventions

Prefix with type and **story id** in parentheses:

| Type | When | Example |
|------|------|---------|
| `chore` | Plans, design-only checkpoints, scaffolding | `chore(PROJ-42): architecture notes and plan` |
| `feat` | Implementation | `feat(PROJ-42): add payment validation` |
| `test` | Tests only | `test(PROJ-42): add unit tests for validator` |
| `docs` | Documentation | `docs(PROJ-42): update API usage` |
| `infra` | Deployment / IaC / pipelines | `infra(PROJ-42): add staging deploy manifest` |

Include a short imperative description after the colon.

## Tag conventions

- **`retry-{story-id}-{n}`**: retry point before attempt `n+1` fixes (or equivalent narrative documented in session).
- Optional: **`gate-pass-{story-id}`** after QualityGate pass if the team wants a clear release pointer (project-specific).

## Safety

- **Never force push** to shared branches.
- **Never `git reset --hard`** on branches others depend on without explicit human approval; default to new commits that revert or fix forward.
- Do not commit secrets or credentials; use secret management per `AGENTS.md`.
