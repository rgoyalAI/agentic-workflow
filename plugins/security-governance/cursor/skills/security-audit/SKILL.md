---
name: security-audit
description: Audits proposed changes for OWASP risks, secrets exposure, and auth/authz correctness.
---
## When to use
- Before accepting security-sensitive changes (auth/authz, secrets, input validation).

## Instructions (required)
1. Load `AGENTS.md` first and follow its deterministic context-loading protocol.
2. Identify trust boundaries and untrusted inputs (user text, PR body, tool output).
3. Verify authentication/authorization enforcement and error handling.
4. Detect sensitive data exposure in logs and artifacts.
5. If you cannot verify evidence from repo context, report `missing-data`.

