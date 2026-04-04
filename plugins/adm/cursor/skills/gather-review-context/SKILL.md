---
name: gather-review-context
description: |
  Gathers the full context bundle for a code review: reads story context, branch metadata, and coding standards from the session manifest, then collects the changed files/diff and runs build/test verification. Returns a Review Context Bundle for use by specialist review agents (ReviewArchitecture, ReviewSecurity, ReviewCode).
---

# Gather Review Context Skill

## Purpose

Collects everything needed to perform a comprehensive code review in one place.
Eliminates repeated context-gathering by each specialist agent — each receives the
same complete bundle so their analysis is consistent and fast.

**Use this skill when:**
- ExecuteStory is preparing to delegate to ReviewArchitecture, ReviewSecurity, and ReviewCode
- A single shared context bundle is needed before parallel specialist reviews begin

## Algorithm

### Step 1: Read Session Manifest

Read the session manifest from `./memories/session/{jira-id}-plan.md` using the memory tool.

Extract and store:
- `{cloudId}` — Jira Cloud ID
- `{jira-id}` — Jira issue key
- `{summary}` — Story summary
- `{description}` — Story description
- `{acceptance_criteria}` — Full acceptance criteria
- `{subtasks}` — Sub-task table
- `{feature_branch}` — Current feature branch name
- `{base_branch}` — Target branch for PR (e.g., develop, main)
- `{languages}` — Detected languages and frameworks
- `{instruction_files}` — Loaded instruction files list

If the manifest is NOT found:
- STOP and report: "⚠️ Session manifest not found at ./memories/session/. StartStory must run first to create the manifest."

Synthesize the manifest data into a **Story Context** block:

```
### Story Context
**{jira-id}**: {summary}

**Description**: {description — condensed to key requirements}

**Acceptance Criteria**:
- [AC from parent story]
- [AC from sub-tasks, if any]

**Functional Requirements** (inferred):
- [What the code must DO, extracted from description + AC]
```

---

### Step 2: Gather Diff and Build Results (Parallel)

The following two activities are **independent**. Issue both in a **single
batch** so they execute in parallel. Collect all results before Step 3.

#### Activity A: Collect Changed Files and Diff

Gather the review scope by combining committed and uncommitted changes:

**Committed changes on the feature branch:**
```
git diff {base_branch}...HEAD --name-only
git diff {base_branch}...HEAD
```

**Uncommitted changes (edge case — e.g., retry after partial fix):**
```
git status --porcelain
git diff HEAD
```

Merge both lists. Filter out non-reviewable files (images, lock files, generated output).
The combined file list is the **review scope**.
The combined diff is the **primary review artifact**.

If no reviewable changes are found, note: "No reviewable changes detected" and include
an empty diff.

#### Activity B: Build & Test Verification

Run the project's build and test suite based on the languages/frameworks recorded in the manifest:

| Build System | Command |
|---|---|
| Maven (`pom.xml`) | `mvn clean verify -q` |
| Gradle (`build.gradle`) | `./gradlew clean check` |
| Node/npm (`package.json`) | `npm ci && npm test` |
| Python (`pyproject.toml` / `requirements.txt`) | `pip install -e ".[test]" && pytest` |
| Go (`go.mod`) | `go test ./...` |

If no build system is detected (e.g., documentation-only or agent-definition changes),
skip and note: "No build system — skipping build/test verification."

Record the outcome:
- **✅ Build & tests pass** — include summary (test count, coverage if available)
- **❌ Build or tests fail** — include the full error output

---

### Step 3: Assemble and Return the Review Context Bundle

Combine manifest data and gathered results into a **Review Context Bundle** and report back naturally:

```
### Review Context Bundle

**Branch**: {feature_branch} → {base_branch}
**Jira ID**: {jira-id}
**Cloud ID**: {cloudId}
**Languages/Frameworks**: {languages from manifest}

---

### Story Context
{From session manifest — synthesized in Step 1}

---

### Changed Files ({count} reviewable files)
{One file per line}

---

### Full Diff
{Complete git diff output}

---

### Build & Test Results
{Summary from Activity B — pass/fail with counts or full error output on failure}

---

**⚠️ Warnings** (omit if none):
- {e.g., "No build system detected"}
```

## When Invoked

ExecuteStory calls this skill before delegating to specialist review agents:
- "Execute skill: gather-review-context"
- "Gather the review context bundle for this branch"

The skill reads the session manifest (written by StartStory), gathers the diff and
build results, and assembles the Review Context Bundle. ExecuteStory then passes this
bundle directly to each specialist agent via `runSubagent`.

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Session manifest not found | StartStory did not run or manifest was deleted | Stop — report error, StartStory must run first |
| Git diff fails | Not in a Git repository or no commits | Stop — report the Git error to ExecuteStory |
| Build/tests fail | Test failures or compile errors | Include full error output in bundle — causes Non-Compliant verdict |
| No reviewable changes | Only images/locks changed | Include empty diff with note; specialists will report Compliant |