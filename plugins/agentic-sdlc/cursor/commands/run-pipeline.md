Run the full SDLC pipeline for: $ARGUMENTS

1. Load `AGENTS.md` and `contexts/PROJECT_CONTEXT.md`
2. Invoke **session-resume** to load cross-session memory
3. If `./memory/` missing, invoke **scaffold-memory**
4. If `contexts/PROJECT_CONTEXT.md` missing, invoke **generate-project-context**
5. Invoke **OrchestrateSDLC** with the requirement
6. Pipeline: Decompose → Plan → Design → Implement → Review → Test → Gate → Complete
7. After completion, invoke **session-wrap-up** to persist learnings

This runs the full autonomous pipeline. For manual step-by-step control, use /start-feature instead.
