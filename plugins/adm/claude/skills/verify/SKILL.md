---
description: Runs required checks/tests to verify changes meet acceptance criteria.
---

Verification is mandatory before final outputs are considered complete.

1. Identify what `AcceptanceCriteria` must be validated.
2. Run the smallest set of appropriate checks:
   - linters/formatters when applicable
   - unit tests
   - integration/contract tests when API/database boundaries changed
3. Summarize pass/fail per criterion and note remaining risks.
4. If checks cannot be run or evidence is missing, output `missing-data`.

Return `VerificationReport`:
- acceptance_criteria_status (pass|fail|missing-data)
- checks (name/command/result)
- remaining_risks

