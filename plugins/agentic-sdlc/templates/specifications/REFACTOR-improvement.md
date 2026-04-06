<!--
How to use: Use for internal quality work. Spell out what must not change behaviorally
before coding; tie success criteria to measurable outcomes where possible.
-->

# Refactoring specification — {{REFACTOR_ID_OR_TITLE}}

## Goals

{{WHAT_IMPROVES}} — **why now:** {{WHY_NOW}}

## Current issues

- {{ISSUE_1}}; {{ISSUE_2}}; {{ISSUE_3}}

## Proposed changes

- [ ] {{CHANGE_1}} · {{CHANGE_2}} · {{CHANGE_3}}

## What stays the same (behavioral preservation)

| Area | Unchanged |
| ---- | --------- |
| API / logic / schema | {{API_UNCHANGED}} · {{LOGIC_UNCHANGED}} · {{SCHEMA_UNCHANGED}} |
| Other | {{OTHER_INVARIANTS}} |

## Migration plan

{{MIGRATION_STEP_1}} → {{MIGRATION_STEP_2}} → {{MIGRATION_STEP_3}} — **rollback:** {{ROLLBACK_PLAN}}

## Success criteria

- [ ] Tests {{TEST_SUCCESS_BAR}} · perf {{PERF_SUCCESS_BAR}} · complexity {{COMPLEXITY_SUCCESS_BAR}}
