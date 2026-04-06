---
name: session-resume
description: Loads the cross-session memory bank at the start of a new session so agents have continuity from previous work. Invoked by the orchestrator in Phase 0.
---

# Session Resume

## When to use

- Start of every orchestrator pipeline run (Phase 0, before decomposition)
- When resuming work after a session handover
- When a new agent instance needs project history

## Steps

1. Check if `./memory/` directory exists. If not, return `SESSION CONTEXT: first run — no prior memory found` and let the orchestrator invoke scaffold-memory.
2. Read these files in order (skip any that are missing or empty):
   - `./memory/project-overview.md` — project identity, tech stack, conventions
   - `./memory/features.md` — what capabilities the system has today
   - `./memory/system-design.md` — how the system is structured (components, data flow, boundaries)
   - `./memory/progress.md` — what's done, in-progress, upcoming
   - `./memory/decisions.md` — architecture decisions and rationale
   - `./memory/open-items.md` — blockers, follow-ups, questions for human
3. Read `./context/sdlc-session.json` if present — pipeline state from the last run (current story, phase, retry count, gate results).
4. Produce a **Session Context Summary**:
   ```
   SESSION CONTEXT:
   project: {name and one-line description from project-overview}
   stack: {backend + frontend + infra summary from project-overview}
   existing_features: {feature list from features.md, or "none yet"}
   system_structure: {components and key boundaries from system-design.md, or "not yet designed"}
   last_completed: {most recent completed items from progress.md}
   in_progress: {current in-progress items from progress.md}
   open_blockers: {from open-items.md, or "none"}
   recent_decisions: {last 3 entries from decisions.md, or "none"}
   pipeline_state: {story, phase, retry from sdlc-session.json, or "no prior session"}
   ```
5. Pass this summary to the orchestrator as loaded context for downstream delegation via A2A envelopes.

## Output

Return the **Session Context Summary** block. If no memory exists, return: `SESSION CONTEXT: first run — no prior memory found`.

## Safety

- **Read-only** — this skill never modifies memory files.
- Redact any secrets or credentials if they appear in memory files.
- If a file is corrupted or unparseable, note `corrupted — skipping {filename}` and continue with readable files.
- Keep the summary concise — extract key facts, not full file contents.
