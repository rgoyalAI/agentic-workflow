---
name: load-contexts
description: Loads only relevant ./contexts/* files using AGENTS.md deterministic protocol.
---

# Load Contexts

Hard rules:
1. Always follow the deterministic context-loading procedure in `AGENTS.md`.
2. Detect project signals using verifiable repo evidence only (file/dir names and contents you can read/search).
3. Load `AGENTS.md` first.
4. Load ONLY the relevant contexts from `./contexts/` using the fixed precedence order defined in `AGENTS.md`.
5. Never hallucinate: if a context file is missing or cannot be read, report it explicitly as `missing-data` and continue.

Detection signals (use the exact criteria from `AGENTS.md`):
- `project.language`: Java -> Python -> Dotnet
- `api_detected`: OpenAPI/Swagger/GraphQL indicators
- `database_detected`: SQL/migrations/Prisma indicators
- `security_detected`: auth/security/jwt/oauth indicators

Output (required):
ContextManifest:
- loaded_contexts: [in the exact load order]
- missing_contexts: [if any, else []]
- detection_signals:
  - project.language: <Java|Python|Dotnet|Unknown>
  - api_detected: <true|false>
  - database_detected: <true|false>
  - security_detected: <true|false>

Instruction to the next step:
- Use ONLY the loaded contexts as the source for additional best practices.

