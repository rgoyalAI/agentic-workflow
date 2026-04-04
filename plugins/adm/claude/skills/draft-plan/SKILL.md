---
description: Drafts an implementation plan with quality gates, acceptance criteria, and verification steps.
---

Create a deterministic, secure, and verifiable plan:

1. Use `load-contexts` (or equivalent logic) to produce a `ContextManifest`.
2. Decompose work into ordered steps with clear module boundaries.
3. Add quality gates after each step (lint/format, unit tests, and contract checks where applicable).
4. Provide `AcceptanceCriteria` (measurable pass/fail checks).
5. If security-sensitive changes are involved, explicitly schedule a `security-auditor` step.
6. If evidence is missing, output `missing-data` or explicit questions.

Planner output:
- ContextManifest
- ProposedPlan (ordered steps)
- AcceptanceCriteria
- VerificationPlan
- SecurityNotes

