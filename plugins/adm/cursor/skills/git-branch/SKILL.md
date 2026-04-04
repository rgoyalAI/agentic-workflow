---
name: git-branch
description: Manages Git branch operations including creating feature branches, detecting base branches, and pushing with tracking. Use when starting or completing story work, creating new branches from Jira tickets, extracting Jira IDs from branch names, validating branch status before commits, or detecting the correct base branch.
---

# Git Branch Management Skill

## Purpose

Provides standardized Git branch operations for the APD workflow: detect base branch automatically, create feature branches following naming conventions, extract Jira IDs from branch names, and validate branch status before operations.

Use when starting work on a new story, completing a story, or ensuring branch follows conventions.

## Algorithm

Agents invoke this skill using task-based descriptions. The skill determines which operation to execute based on the task.

### 1. Create Feature Branch

**Algorithm:**

1. **Detect base branch** (remote HEAD)
2. **Generate branch name**: `feature/{jira-id}-{descriptive-name}` (lowercase, hyphens, max 50 chars)
3. **Execute Git commands**:
   ```bash
   git fetch origin
   git checkout {base_branch}
   git pull origin {base_branch}
   git checkout -b feature/{jira-id}-{name}
   git push -u origin feature/{jira-id}-{name}
   ```
4. **Verify success** and report status

**Inputs:** `jira_id` (required), `summary` (optional), `base_branch` (optional)

### 2. Extract Jira ID from Branch

**Algorithm:**

1. **Get branch name**: Use provided branch or execute `git branch --show-current`
2. **Extract Jira ID** using regex: `^(feature|bugfix|hotfix|docs)/([A-Z]+-\d+)-`
3. **Return**: Jira ID if match found (e.g., "SITAMS-5565"), `null` if no match

**Examples:**
- `feature/SITAMS-5565-extract-skill` → `"SITAMS-5565"` ✅
- `bugfix/PROJ-123-fix-auth` → `"PROJ-123"` ✅
- `main` → `null` ❌

**Inputs:** `branch_name` (optional, defaults to current)

### 3. Validate Branch Status

**Checks:**

1. **All changes committed**: Working directory clean (`git status --porcelain` returns empty)
2. **Branch has commits**: Local branch is ahead of base branch
3. **Remote tracking configured**: Branch has upstream set
4. **Local/remote synchronized**: Local and remote at same commit

Returns validation status with list of any issues found.

**Inputs:** `branch_name` (optional, defaults to current)

### 4. Get Base Branch

**Algorithm:** Detect in priority order: develop > main > master > remote HEAD

Returns detected base branch name.

## When Invoked

Agents call this skill with natural language tasks:
- "Create a feature branch for SITAMS-5700 with summary: Trim agent skills"
- "Extract the Jira ID from the current branch name"
- "Validate that the current branch is ready for pull request"
- "Detect the base branch for this repository"

The skill determines what operation to perform based on the task description and executes it.

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Authentication failure | Invalid Git credentials | Update credentials, check SSH keys |
| Network error | Connectivity issue | Check network, verify repository access |
| Existing branch conflict | Branch already exists | Use different name or delete existing branch |
| Missing base branch | Repository not initialized | Initialize repository with base branch |
