---
name: jira-operations
description: Manages Jira operations including creating, editing, transitioning, and searching issues using the Atlassian MCP. Use when working with Jira issues, transitioning status, creating stories or sub-tasks, searching with JQL, assigning issues, or adding comments. Handles cloudId resolution, transition ID lookups, and field format requirements.
---

# Jira Operations Skill

Provides standardized Jira operations for APD workflows. Prevents common agent errors with cloudId, transitions, and field formats.

## Quick Reference

### CloudId (REQUIRED FIRST)

```
getAccessibleAtlassianResources → Extract "id" field (UUID), NOT "name"
```
- ✅ `cloudId: "5e02de79-c796-455e-a4c5-4b6544321311"`
- ❌ `cloudId: "gm-sdv"` (this is the site name, not cloudId)

### Field Formats (SITAMS)

| Field | Key | Format | Required on Create? |
|-------|-----|--------|---------------------|
| Story Points | `customfield_10031` | `5` (integer) | ✅ Story/Feature |
| Team | `customfield_10001` | `"uuid-string"` (plain string, NOT object) | ✅ Story/Feature |
| Acceptance Criteria | `customfield_10046` | ADF object (see below) | ✅ Story/Feature |
| Labels | `labels` | `["label1", "label2"]` | ✅ Story/Feature |
| GM APM Number | `customfield_10558` | `"string"` | ✅ Story/Feature |
| GM Persistent Team | `customfield_10562` | `"string"` | ✅ Story/Feature |
| Epic Link | `customfield_10014` | `"PROJ-123"` | Optional |
| GM Product Type | `customfield_10591` | `{"id": "string"}` (select) | Optional |
| GM Blocked | `customfield_10596` | `{"id": "14606"}` (No) | Optional |
| Start date | `customfield_10015` | `"YYYY-MM-DD"` | Optional |

### Required Field Inheritance (MANDATORY)

**Before creating Stories or Features, you MUST obtain required field values:**

1. **Fetch parent/source issue** with fields: `customfield_10558`, `customfield_10562`, `customfield_10591`, `customfield_10001`, `labels`, `project`
2. **Extract projectKey** from parent/source issue's `project.key` field
3. **If parent exists**, fetch parent with same fields (prefer parent values over source)
4. **Inherit values** from parent → source issue → prompt user
5. **If any required field is missing after inheritance**, prompt user:
   ```
   Missing required fields for Story creation:
   - GM APM Number (customfield_10558): [not found]
   - GM Persistent Team (customfield_10562): [not found]
   - Team (customfield_10001): [not found]
   
   Please provide values or specify a source issue to inherit from.
   ```

⚠️ **NEVER use placeholder values.** Always inherit from parent or prompt user.

**Inheritance Priority:** Parent Issue → Source Issue → User Input

### Parameter Names (MCP-specific)

| ❌ Wrong | ✅ Correct |
|---------|-----------|
| `assigneeAccountId` | `assignee_account_id` |
| `transitionId` | `transition` |
| `body` | `commentBody` |
| `issueTypeId` | `issueTypeName` |
| `email` | `searchString` |
| `parent` in additional_fields | `parent` as top-level string |

---

## Operations

### 1. Create Issue

```json
{
  "cloudId": "<from getAccessibleAtlassianResources>",
  "projectKey": "<from parent issue project.key>",
  "issueTypeName": "Story",
  "summary": "Implement feature X",
  "description": "## Overview\n**Purpose:** ...",
  "additional_fields": {
    "customfield_10031": 5,
    "customfield_10001": "<inherit from parent or prompt user>",
    "customfield_10046": {"type": "doc", "version": 1, "content": [...]},
    "labels": ["ai-planned", "<inherit from parent>"],
    "customfield_10558": "<inherit from parent or prompt user>",
    "customfield_10562": "<inherit from parent or prompt user>"
  }
}
```

**Sub-task Creation:**
```json
{
  "cloudId": "<from getAccessibleAtlassianResources>",
  "projectKey": "<from parent issue project.key>",
  "issueTypeName": "Sub-task",
  "summary": "Implement database migration",
  "description": "Task details...",
  "parent": "PROJ-1234"
}
```

⚠️ **CRITICAL:**
- `parent` is a **top-level parameter** (plain string key), NOT inside `additional_fields`, NOT an object `{"key": "..."}`
- Sub-tasks **automatically inherit** Team, GM APM Number, GM Persistent Team, and other fields from their parent Story
- Do NOT specify inherited fields when creating Sub-tasks

**Issue Types:** `"Story"`, `"Sub-task"`, `"Defect"`, `"ART Feature"`

### 2. Edit Issue

```json
{
  "cloudId": "...",
  "issueIdOrKey": "SITAMS-5892",
  "fields": {
    "summary": "New Title",
    "customfield_10031": 8
  }
}
```

**Field type formats:**
- String: `"value"`
- Number: `5`
- Select: `{"id": "30501"}`
- User: `{"accountId": "712020:..."}`
- Date: `"2026-02-15"`

### 3. Transition Issue

**Algorithm:**
1. Call `getTransitionsForJiraIssue` → get available transitions
2. Find transition by **name**, extract its **id**
3. Call `transitionJiraIssue` with transition object

```json
{
  "cloudId": "...",
  "issueIdOrKey": "SITAMS-5892",
  "transition": {"id": "21"}
}
```

**⚠️ CRITICAL:** Use transition `id`, NOT status `id`:
```json
// Response from getTransitionsForJiraIssue
{
  "id": "21",              // ← USE THIS (transition ID)
  "name": "Work in progress",
  "to": {"id": "10099"}    // ← NOT THIS (status ID)
}
```

**Transition IDs vary by issue type!** Always query first.

### 4. Search (JQL)

```json
{
  "cloudId": "...",
  "jql": "project = SITAMS AND status = \"Work in progress\"",
  "fields": ["summary", "status", "assignee"],
  "maxResults": 50
}
```

### 5. Add Comment

```json
{
  "cloudId": "...",
  "issueIdOrKey": "SITAMS-5892",
  "commentBody": "Comment text here"
}
```

### 6. Lookup User

```json
{
  "cloudId": "...",
  "searchString": "francisco.tineomateo@gm.com"
}
```
Returns: `accountId` like `"712020:6f01bbf7-df86-4b86-a909-0d4384d627d3"`

---

## Acceptance Criteria (ADF Format)

**Description field:** Pass markdown → auto-converts to ADF.

**Acceptance Criteria (customfield_10046):** Pass ADF object → NO auto-conversion!

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [{"type": "text", "text": "Scenario: Happy path", "marks": [{"type": "strong"}]}]
    },
    {
      "type": "paragraph",
      "content": [
        {"type": "text", "text": "Given precondition"},
        {"type": "hardBreak"},
        {"type": "text", "text": "When action"},
        {"type": "hardBreak"},
        {"type": "text", "text": "Then result"}
      ]
    }
  ]
}
```

---

## Common Mistakes

| # | Mistake | Fix |
|---|---------|-----|
| 1 | CloudId = site name | Call `getAccessibleAtlassianResources`, use `id` field |
| 2 | Status ID for transitions | Use transition `id` from `getTransitionsForJiraIssue` |
| 3 | Hardcoded transition IDs | Always query transitions (vary by issue type) |
| 4 | Wrong parameter names | See Parameter Names table above |
| 5 | Select value as string | Use `{"id": "30501"}` object format |
| 6 | Transition ID as number | Use string: `{"id": "21"}` not `{"id": 21}` |
| 7 | AC in description field | Use `customfield_10046` with ADF object |
| 8 | Labels in description | Use `labels` array field |
| 9 | Team as object | Use plain string UUID, not `{"id": "..."}` |
| 10 | editJiraIssue for status | Use `transitionJiraIssue` |
| 11 | Missing required fields | Include all fields marked ✅ in Quick Reference |
| 12 | `parent` in additional_fields | Use `parent` as top-level string param |
| 13 | `parent` as object `{"key": "..."}` | Use plain string: `"SITAMS-5892"` |
| 14 | Using placeholder/hardcoded values | Inherit from parent issue or prompt user |
| 15 | Specifying inherited fields on Sub-task | Sub-tasks auto-inherit from parent Story |
| 16 | Hardcoded projectKey | Extract from parent issue `project.key` |

---

## Error Resolution

| Error | Cause | Fix |
|-------|-------|-----|
| "Bad Request" on edit | Wrong field format | Check Quick Reference for correct format |
| "Transition id X is not valid" | Wrong ID or workflow | Call `getTransitionsForJiraIssue` first |
| "must have required property" | Wrong parameter name | Check Parameter Names table |
| "must be object" | Transition format | Use `{"id": "21"}` object |
| "Team id 'JsonData...' is not valid" | Team as object | Use plain string UUID |

---

## Golden Path Workflows

### Create Story (Complete)
```
1. getAccessibleAtlassianResources → cloudId
2. getJiraIssue (parent/source) → extract required fields
3. If fields missing → prompt user for values
4. createJiraIssue with inherited/provided fields
```

### Assign Issue to User
```
1. getAccessibleAtlassianResources → cloudId
2. atlassianUserInfo → get current user's accountId
3. editJiraIssue(cloudId, issueKey, {"assignee": {"accountId": "<accountId>"}})
```

⚠️ The `assignee` field requires an object with `accountId`, not just the ID string.

### Fetch Full Story Context

Fetches the parent story and all its children in **parallel** — a single skill invocation that replaces the need for separate story and sub-task calls.

**Algorithm:**

```
# Run both in parallel:
A. searchJiraIssuesUsingJql(
     cloudId,
     jql: "key = {storyKey}",
     fields: ["summary", "description", "issuetype", "customfield_10046"],
     maxResults: 1
   )
   → story: {key, summary, description, issuetype, acceptance_criteria}

B. searchJiraIssuesUsingJql(
     cloudId,
     jql: "parent = {storyKey}",
     fields: ["summary", "description"],
     maxResults: 100
   )
   → children: [{key, summary, description}], totalCount: N

Return combined result: {story, children, childCount: totalCount from B}
```

**Why this pattern:**
- Uses `searchJiraIssuesUsingJql` for both calls (not `getJiraIssue`) because, in the current Atlassian MCP implementation, JQL search returns `customfield_10046` (Acceptance Criteria) when explicitly requested — `getJiraIssue` typically omits it. **Whenever Acceptance Criteria is needed, prefer `searchJiraIssuesUsingJql`.** (Note: `getJiraIssue` is still appropriate for fetching standard fields like Team, Labels, and Epic Link — see "Create Story (Complete)" golden path.)
- Uses `parent = X` without `subTaskIssueTypes()` filter — the filter only matches Sub-task types and **silently returns 0 results** for Feature→Story hierarchy. Bare `parent =` works universally across all hierarchy levels
- Call B returns `totalCount` which is the **definitive child count** — use this for manifest validation
- `maxResults: 100` covers all practical story sizes; if `totalCount > 100`, re-invoke Call B with `startAt: 100` to fetch remaining children before writing the manifest

⚠️ **CRITICAL — Large responses:** Jira responses include full `project`, `assignee`, `status` objects with avatar URLs regardless of which fields you request. For stories with many children (e.g., 25 sub-tasks = ~110KB), the response will be large. **You MUST read the entire response** — do not skip, truncate, or summarize. Every child issue's `key`, `summary`, and `description` are required for the session manifest.

**Notes:**
- `customfield_10046` (Acceptance Criteria) is always `null` on Sub-tasks — all detail is in `description`
- If no children exist, `children` will be an empty list and `totalCount` will be 0
- Requires `cloudId` to be resolved first (via `getAccessibleAtlassianResources`)
- **Record `totalCount` from Call B** — StartStory uses this for manifest validation

---

### Bulk Assign and Transition (Story + Sub-tasks)

Assigns and/or transitions a Story and all its Sub-tasks in a single workflow. Used by StartStory, CompleteStory, and similar agents.

**Inputs:**

| Input | Required | Description |
|-------|----------|-------------|
| storyKey | Yes | The Jira issue key (e.g., "SITAMS-5892") |
| storyTargetStatus | Yes | Target status for the Story |
| subtaskTargetStatus | Yes | Target status for all Sub-tasks |
| assignToMe | No | Whether to assign issues to current user (default: false) |
| cloudId | No | If provided, skip step 1 (use cached cloudId from session manifest) |
| subtasks | No | If provided, skip step 3 (use cached sub-task list from session manifest). Must be objects with at least a `key` field (e.g., `[{key: "PROJ-101", summary: "...", status: "..."}]`) |

**Common Scenarios:**

| Scenario | storyTargetStatus | subtaskTargetStatus | assignToMe |
|----------|-------------------|---------------------|------------|
| Start Story | "Work in progress" | "Work in progress" | true |
| Complete Story | "Ready for testing" | "Completed" | false |
| Cancel Story | "Cancelled" | "Cancelled" | false |

**Algorithm:**

```
# SETUP (do once)
1. If cloudId provided: use it; otherwise getAccessibleAtlassianResources → cloudId
2. If assignToMe: atlassianUserInfo → accountId

# GET SUB-TASKS + TRANSITION IDs (once per issue type)
3. If subtasks provided: use them as subtaskList; otherwise:
   searchJiraIssuesUsingJql(cloudId, jql: "parent = {storyKey}", fields: ["summary", "status"], maxResults: 100) → subtaskList
   ⚠️ Do NOT use getJiraIssue to fetch sub-tasks — the subtasks field is unreliable across MCP implementations. Always use JQL search.
   ⚠️ Do NOT add `issueType in subTaskIssueTypes()` — it silently returns 0 results for Feature→Story hierarchy. Bare `parent =` works universally.
4. getTransitionsForJiraIssue(cloudId, storyKey) → find storyTargetStatus → storyTransitionId
5. If subtaskList not empty:
   - getTransitionsForJiraIssue(cloudId, subtaskList[0].key) → find subtaskTargetStatus → subtaskTransitionId
   ⚠️ Query ANY ONE Sub-task—all Sub-tasks of same type share the same workflow

# PROCESS PARENT STORY
6. If assignToMe: editJiraIssue(cloudId, storyKey, {"assignee": {"accountId": "<accountId>"}})
7. transitionJiraIssue(cloudId, storyKey, {"transition": {"id": "<storyTransitionId>"}})

# PROCESS EACH SUBTASK (loop, reuse subtaskTransitionId)
For each subtask in subtaskList:
  8. If assignToMe: editJiraIssue(cloudId, subtask.key, {"assignee": {"accountId": "<accountId>"}})
  9. transitionJiraIssue(cloudId, subtask.key, {"transition": {"id": "<subtaskTransitionId>"}})
```

**Critical Notes:**
- **Transition IDs are per issue type**, not per issue—query once for Stories, once for Sub-tasks
- Reuse `cloudId`, `accountId`, and `subtaskTransitionId` throughout—do NOT re-query
- If an issue is already in target status, the transition won't be available—skip it gracefully
- Sub-tasks and Stories have DIFFERENT workflows—their transition IDs will differ
