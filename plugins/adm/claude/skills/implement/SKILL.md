---
description: Implements a proposed plan while enforcing security and verification gates.
---

Implement ONLY what the plan/acceptance criteria require:

1. Execute steps sequentially.
2. After each implementation step, run the smallest relevant checks (lint/format, unit tests, integration/contract checks as applicable).
3. If a step includes security-sensitive surface area (auth/authz, secrets, validation boundaries, database writes/destructive ops), require a `security-auditor` pass before finalizing.
4. Never proceed if verification cannot be completed; output `missing-data`.

Return `ImplementationResult`:
- artifacts_changed
- steps_completed
- tests_ran (pass|fail|missing-data)
- security_review_status (pass|pending|fail|missing-data)
- risks_remaining

