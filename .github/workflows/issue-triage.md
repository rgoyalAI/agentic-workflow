---
description: "Automatically triage new issues"
on:
  issues:
    types: [opened]
permissions:
  contents: read
  issues: read
tools:
  github:
    toolsets: [default]
safe-outputs:
  add-comment:
    max: 1
  update-issue:
    max: 1
---

# Issue Triage Agent

When a new issue is opened:
1. Read the issue title, body, and any code snippets
2. Classify it as bug, feature, question, docs, or chore
3. Assess priority (critical, high, medium, low)
4. Apply the appropriate labels
5. Post a helpful response acknowledging the submission