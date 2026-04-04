---
description: Deterministically loads AGENTS.md + relevant contexts (no hallucination).
---

Load `AGENTS.md` first, then follow its deterministic context-loading protocol:

1. Detect project signals using only verifiable repo evidence (file names/paths you can read).
2. Load ONLY the relevant context files from `./contexts/` in this fixed order:
   - Language context (exactly one): `java` then `python` then `dotnet`
   - Domain contexts (may be multiple): `api-design` then `database` then `security`
3. If a context file is missing/unreadable, do not hallucinate it. Continue with what is available and record missing files.

Return a `ContextManifest` with:
- detected project.language (or `Unknown`)
- detected domain contexts
- `contexts_loaded`: paths loaded
- `contexts_missing`: paths missing/unreadable

