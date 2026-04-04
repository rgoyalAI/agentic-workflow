---
name: security-check
description: Performs OWASP/security + secrets handling review for proposed changes using AGENTS.md and security context.
---

# Security Check

Hard rules:
1. Always follow `AGENTS.md`.
2. Never recommend bypassing auth, disabling TLS, or weakening validation.
3. Never propose secret leakage; redact findings and require evidence from repo context.
4. If you cannot verify an assertion with available context, report `missing-data`.

Inputs (if available in the conversation):
- The proposed changes (file paths + diff or descriptions)
- Loaded_contexts (especially security/api/database contexts)

Output format (required):
SecurityFindings:
- severity: Critical|High|Medium|Low
  finding: <what is wrong>
  evidence: <file/path + short quote or exact reference>
  impact: <what could go wrong>
  required_fix: <specific change>

VerificationPlan:
- <checks/tests to run>

