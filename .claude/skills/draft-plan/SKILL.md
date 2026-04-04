---
name: draft-plan
description: Creates an enterprise implementation plan with acceptance criteria using AGENTS.md and loaded contexts.
---

# Draft Plan

Hard rules:
1. Always follow `AGENTS.md`.
2. Planning only: do not implement code in this skill.
3. If `missing_contexts` is non-empty, avoid unverifiable steps and output what remains unknown.

Plan requirements (required sections):
1. Summary
2. Assumptions
3. ProposedPlan (ordered steps)
4. Module boundaries (what files/components are expected to touch)
5. AcceptanceCriteria (measurable pass/fail)
6. VerificationPlan (tests/lints/checks to run)
7. SecurityNotes (risks guarded + how verified)
8. MissingData (only when necessary)

Inter-agent handoff:
- When delegating, include the A2A envelope verbatim from `AGENTS.md`.

