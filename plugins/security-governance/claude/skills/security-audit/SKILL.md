---
description: Audits proposed changes for OWASP risks, secrets exposure, and authorization correctness. Always follow `AGENTS.md`.
---
## When to use
- Before accepting security-sensitive changes (auth/authz, secrets handling, input validation).

## Instructions
1. Follow the deterministic context-loading protocol from `AGENTS.md`.
2. Identify trust boundaries and untrusted inputs.
3. Verify auth/authz enforcement and error handling consistency.
4. Detect sensitive data exposure in logs/artifacts.
5. If evidence cannot be verified, report `missing-data`.

