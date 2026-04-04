---
name: load-contexts
description: Deterministically detects project signals and loads only the relevant ./contexts/* files using AGENTS.md.
---

# Load Contexts (Deterministic)

Hard rules:
1. Always follow `AGENTS.md`.
2. Load `AGENTS.md` first.
3. Detect signals using verifiable repo evidence only (use `Glob`/`Grep`/`Read` to confirm file presence and contents).
4. Load ONLY relevant contexts from `./contexts/` in the fixed precedence order from `AGENTS.md`.
5. Never hallucinate missing context. If a context file is unavailable in your session, output `missing-data` and continue.

Detection signals (use AGENTS.md criteria):
- project.language: Java -> Python -> Dotnet
- api_detected
- database_detected
- security_detected

Output format (required):
ContextManifest:
- loaded_contexts: [exact load order]
- missing_contexts: [if any else []]
- detection_signals:
  - project.language: Java|Python|Dotnet|Unknown
  - api_detected: true|false
  - database_detected: true|false
  - security_detected: true|false

