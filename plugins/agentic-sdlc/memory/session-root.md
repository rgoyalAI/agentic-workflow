---
session_id: {{SESSION_ID}}
started_at: {{ISO_8601}}
status: in_progress
source: prompt|jira
source_id: "{{RAW_TEXT_HASH_OR_JIRA_ID}}"
branch: feature/sdlc-{{SESSION_ID_SHORT}}
---

# Session Root

## Stories
<!-- Auto-populated by DecomposeRequirements -->
| # | Story ID | Title | Status | Retry Count | Dependencies |
|---|----------|-------|--------|-------------|--------------|

## Detected Stack
- **Language**: {{LANGUAGE}}
- **Framework**: {{FRAMEWORK}}
- **Build**: {{BUILD_CMD}}
- **Test**: {{TEST_CMD}}

## Coding Standards Loaded
- `standards/coding/naming-conventions.md`
- `standards/coding/exception-handling.md`
- `languages/{{LANG}}/{{FRAMEWORK}}.md`

## Progress
| Phase | Status | Agent | Started | Completed | Tokens Used |
|-------|--------|-------|---------|-----------|-------------|

## Configuration
- Coverage threshold: 80%
- Max retries per story: 3
- Human-in-the-loop: optional (before CompleteStory)
- E2E testing: enabled
- Deployment generation: enabled

## Cumulative Metrics
- Total tokens: 0
- Total duration: 0ms
- Stories completed: 0/{{TOTAL}}
