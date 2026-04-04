---
name: draft-plan
description: Produces an enterprise implementation plan with acceptance criteria using AGENTS.md and loaded contexts.
---

# Draft Plan

Hard rules:
1. Always follow `AGENTS.md`.
2. Do not implement; planning only.
3. Start from the `ContextManifest` (loaded contexts + missing contexts) if provided.
4. If `missing_contexts` is non-empty, either:
   - request the user for missing info, or
   - produce a plan that avoids unverifiable steps and explicitly lists what remains unknown.

Plan requirements (required sections):
1. Summary
2. Assumptions
3. ProposedPlan (ordered steps)
4. Module boundaries (what files/components you expect to touch)
5. AcceptanceCriteria (measurable pass/fail checks)
6. VerificationPlan (what tests/lints/checks to run)
7. SecurityNotes (what risks you specifically guarded against)
8. MissingData (only when necessary)

Inter-agent handoff (required):
When delegating to another agent, include the A2A envelope verbatim from `AGENTS.md`.

