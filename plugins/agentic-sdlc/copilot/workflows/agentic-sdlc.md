# Workflow: Agentic SDLC pipeline (reference)

This document describes an optional **GitHub Actions** entry point for teams that want CI to **signal** or **gate** an SDLC pipeline. Fully autonomous multi-agent execution is **not** available in Actions; use this workflow for **validation jobs**, **artifact collection**, or **manual dispatch** that pairs with Copilot/IDE work.

## Installation

Copy the YAML below to **`.github/workflows/agentic-sdlc.yml`** in your repository. Customize branches, permissions, and secrets.

## Workflow: `agentic-sdlc.yml`

Triggers on `workflow_dispatch` so maintainers can run a structured pipeline check after feature work. Add `pull_request` if you want the same jobs on every PR (may duplicate `ci-quality-gate`).

```yaml
name: agentic-sdlc

on:
  workflow_dispatch:
    inputs:
      story_id:
        description: "Story id (e.g. STORY-001)"
        required: false
        type: string

permissions:
  contents: read

concurrency:
  group: agentic-sdlc-${{ github.ref }}
  cancel-in-progress: false

jobs:
  context-check:
    name: Verify AGENTS.md and context paths
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Require AGENTS.md
        run: |
          test -f AGENTS.md || (echo "AGENTS.md missing at repo root" && exit 1)

      - name: Optional context folder
        run: |
          if [ -d context ]; then echo "./context present"; ls -la context || true; else echo "No ./context directory (optional)"; fi

  notify:
    name: SDLC handoff note
    runs-on: ubuntu-latest
    needs: [context-check]
    steps:
      - name: Summary
        run: |
          echo "Agentic SDLC: complete implementation and reviews in the IDE/Copilot/Claude."
          echo "Use ./context/sdlc-session.json and quality-gate-report.md when adopting the full contract."
```

## Notes

- **Secrets:** add OIDC/registry auth only when this workflow builds or deploys; keep tokens out of logs.  
- **Integration:** point subsequent jobs to your real build/test actions or reuse **`ci-quality-gate`** workflow jobs via `workflow_call` if you split workflows.
