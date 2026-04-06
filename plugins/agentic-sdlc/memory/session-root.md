<!--
Session Root — reference template for ./context/sdlc-session.json

This file documents the schema for the pipeline session file.
The actual runtime state lives in ./context/sdlc-session.json (JSON).
Cross-session persistent knowledge lives in ./memory/ (markdown files).

Relationship:
  ./context/sdlc-session.json  — ephemeral pipeline state (per-run, may be reset)
  ./memory/                    — persistent knowledge bank (survives across sessions)
-->

# Session Root Schema

## `./context/sdlc-session.json` fields

```json
{
  "sessionId": "<UUID>",
  "startedAt": "<ISO-8601>",
  "status": "in_progress | completed | failed | escalated",
  "inputType": "prompt | jira",
  "sourceId": "<raw-text-hash or JIRA-ID>",
  "branch": "feature/sdlc-<short-id>",
  "storiesPath": "./context/stories.json",
  "stories": [
    {
      "id": "STORY-001",
      "title": "<title>",
      "status": "pending | in_progress | completed | failed | escalated",
      "retryCount": 0,
      "currentPhase": "plan | design | implement | review | test | e2e | gate | complete",
      "lastCheckpoint": "<git-tag-or-commit>",
      "gateVerdict": "pass | fail | pending",
      "dependencies": ["STORY-000"]
    }
  ],
  "detectedStack": {
    "backend": { "language": "<lang>", "framework": "<fw>", "buildTool": "<tool>" },
    "frontend": { "language": "<lang>", "framework": "<fw>", "buildTool": "<tool>" },
    "database": "<type or none>",
    "infrastructure": "<docker/k8s/terraform or none>"
  },
  "configuration": {
    "coverageThreshold": 80,
    "maxRetriesPerStory": 3,
    "humanInTheLoop": false,
    "e2eEnabled": true,
    "deploymentGeneration": true
  },
  "metrics": {
    "totalTokens": 0,
    "totalDurationMs": 0,
    "storiesCompleted": 0,
    "storiesTotal": 0
  }
}
```

## `./memory/` directory (cross-session)

| File | Purpose | Updated by |
|------|---------|------------|
| `project-overview.md` | Identity, tech stack, conventions | `scaffold-memory`, `session-wrap-up` (on stack changes) |
| `features.md` | Living feature inventory — what the system can do | `session-wrap-up` (after stories that add capabilities) |
| `system-design.md` | Cumulative architecture — components, data flow, boundaries | `session-wrap-up` (after design-impacting stories) |
| `progress.md` | Completed / in-progress / upcoming | `session-wrap-up` (after each story) |
| `decisions.md` | Architecture decisions log | `session-wrap-up` (when decisions are made) |
| `open-items.md` | Blockers, follow-ups, questions | `session-wrap-up` (add/resolve items) |

**Note:** `system-design.md` is the **persistent high-level** view. The per-story `./context/architecture.md` is the **detailed ephemeral** design artifact — it feeds into `system-design.md` via `session-wrap-up`.

## Lifecycle

1. **Phase 0**: `session-resume` reads `./memory/` → `scaffold-memory` if missing → `generate-project-context` if needed → init `sdlc-session.json`
2. **Per story**: Orchestrator updates `sdlc-session.json` at each phase transition
3. **Phase 8**: `session-wrap-up` persists learnings to `./memory/`
4. **Final**: Last `session-wrap-up` + final report
