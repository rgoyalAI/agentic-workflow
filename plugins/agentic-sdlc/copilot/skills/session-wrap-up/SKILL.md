---
name: session-wrap-up
description: Persists session learnings, decisions, and progress to the ./memory/ bank after completing work. Run after each story completion, pipeline run, or before ending a long session.
---

# Session Wrap-Up

## When to use

- After completing a story (orchestrator Phase 8)
- After a significant debugging or implementation session
- Before ending a long session or when context pressure triggers handover
- When the orchestrator completes all stories (final wrap-up)

## Steps

1. **Ensure ./memory/ exists** — if not, invoke **scaffold-memory** first.
2. **Update `./memory/progress.md`**:
   - Move completed items from "In Progress" to "Completed" with today's date.
   - Add any new in-progress or upcoming items discovered during the session.
   - Append to "Lessons Learned" if meaningful patterns emerged (what worked, what didn't).
3. **Update `./memory/decisions.md`**:
   - Append one row per meaningful decision made during this session.
   - Include: date, decision summary, context/trigger, alternatives rejected, status (Accepted).
   - Do not duplicate decisions already in the log.
4. **Update `./memory/open-items.md`**:
   - Add new blockers, follow-ups, or human questions discovered.
   - Remove items that were resolved during this session (move to progress.md as completed).
5. **Update `./memory/features.md`**:
   - After a story completes, add its delivered capabilities to the feature table.
   - Include: feature name, story ID, status (active/deprecated), brief notes.
   - If the story only refactored or fixed bugs without new capabilities, skip.
6. **Update `./memory/system-design.md`**:
   - After a story that changes architecture (new component, new integration, changed data flow), update the relevant section.
   - Summarize from `./context/architecture.md` if it was produced this session — extract high-level components, data flow, and boundaries only (not full detail).
   - Skip if the story was purely cosmetic or bug-fix with no structural changes.
7. **Update `./memory/project-overview.md`** only if:
   - Tech stack changed (new dependency, framework migration).
   - Team conventions changed (new branch naming, review process).
   - Otherwise skip to avoid churn.
8. **Update `./context/sdlc-session.json`** — mark current story phase, retry count, gate status, timestamp.
7. **Commit** memory updates: `docs(memory): session wrap-up — {summary}` (replace `{summary}` with 3-5 word description like "completed STORY-42 implementation").

## Output

Return a **list of memory files updated** (paths relative to repo root) and a one-line summary of what changed.

## Safety

- Never store secrets, tokens, credentials, or private keys in memory files.
- Keep entries concise and factual — prefer bullet lists over prose.
- Use `missing-data` for unknowns instead of guessing dates, owners, or outcomes.
- Before committing, verify no PII or env-specific values were pasted into `./memory/`.

## Tips

- Reference story or ticket IDs in progress notes when available.
- If nothing material changed, skip file updates — avoid churn.
- For multi-story sessions, batch updates: one wrap-up after all stories, not per-story.
