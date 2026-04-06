---
name: scaffold-memory
description: Creates the ./memory/ directory structure with initial files for cross-session persistence. Run once when onboarding a new project or when ./memory/ is missing.
---

# Scaffold Memory Bank

## When to use

- First pipeline run on a new project (orchestrator Phase 0, after generate-project-context)
- When `./memory/` directory does not exist
- After cloning a repo that uses this framework but lost its memory directory

## Steps

1. Check if `./memory/` exists and contains files with non-placeholder content. If so, **skip** — memory is already initialized.
2. Create the directory and six files:
   ```
   ./memory/
   ├── project-overview.md   # Identity, stack, conventions
   ├── features.md           # Living feature inventory — what the system can do
   ├── system-design.md      # Cumulative architecture — how the system is structured
   ├── progress.md           # Completed / in-progress / upcoming
   ├── decisions.md          # Architecture decision log
   └── open-items.md         # Blockers, follow-ups, questions
   ```
3. **`project-overview.md`** — if `contexts/PROJECT_CONTEXT.md` exists, copy the "What This Is", "Tech Stack", and "Key Principles" sections. Otherwise write section headers with `unknown — run generate-project-context first`.
4. **`features.md`** — write empty structure:
   ```markdown
   # Feature Inventory
   Living list of capabilities this system provides. Updated as stories complete.
   ## Features
   | Feature | Story | Status | Notes |
   |---------|-------|--------|-------|
   ## Integrations
   (none yet)
   ```
5. **`system-design.md`** — write initial structure:
   ```markdown
   # System Design
   Cumulative architecture knowledge. Updated when design-impacting stories complete.
   ## Components
   (none yet — populated after first architecture phase)
   ## Data Flow
   (none yet)
   ## Integration Points
   (none yet)
   ## Security Boundaries
   (none yet)
   ```
   If `./context/architecture.md` exists from a prior run, extract and summarize the high-level components, data flow, and boundaries into this file.
6. **`progress.md`** — write empty structure:
   ```markdown
   # Implementation Progress
   ## Completed
   (none yet)
   ## In Progress
   (none yet)
   ## Upcoming
   (none yet)
   ## Lessons Learned
   (none yet)
   ```
7. **`decisions.md`** — write table headers:
   ```markdown
   # Architecture Decisions
   | Date | Decision | Context | Alternatives Rejected | Status |
   |------|----------|---------|----------------------|--------|
   ```
8. **`open-items.md`** — write empty structure:
   ```markdown
   # Open Items
   ## Blockers
   (none)
   ## Follow-ups
   (none)
   ## Questions for Human
   (none)
   ```
9. Commit: `docs(memory): scaffold memory bank`

## Output

Return the list of created file paths under `./memory/`.

## Safety

- Never overwrite existing memory files that contain real (non-placeholder) content.
- No secrets, credentials, or environment-specific values in memory files.
- If `contexts/PROJECT_CONTEXT.md` contains sensitive data, redact before copying to project-overview.
