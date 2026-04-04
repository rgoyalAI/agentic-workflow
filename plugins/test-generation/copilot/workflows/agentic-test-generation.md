---
description: Agentic test generation workflow (gh-aw style)
on:
  pull_request:
    types: [opened, synchronize]
permissions:
  contents: read
  pull-requests: read
tools:
  github:
    toolsets: [default]
  grep: true
  glob: true
engine: copilot
sandbox:
  type: default
  agent: false
strict: false
safe-outputs:
  add-comment:
    max: 1
---

# Agentic Test Generation

Hard rules:
1. Always follow `AGENTS.md` as the single source of truth.
2. Deterministic testing mindset (MUST):
   - Prefer deterministic fixtures and no wall-clock-dependent assertions.
   - Follow existing repo test framework and conventions.
3. Missing-data behavior (MUST):
   - If you cannot verify expected behavior from repo context, report `missing-data`.

When triggered:
1. Identify changed code paths that require regression tests.
2. Propose a test plan (framework, scope, cases).
3. Request an allowed safe output:
   - `add-comment` with the test plan and verification steps.

