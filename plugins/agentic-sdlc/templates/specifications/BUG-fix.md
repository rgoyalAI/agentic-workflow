<!--
How to use: Complete before implementation of a fix. Attach logs, IDs, and links;
keep reproduction steps minimal but reliable for whoever verifies the fix.
-->

# Bug fix specification — {{BUG_ID_OR_TITLE}}

## Problem

| | |
| --- | --- |
| **Current** | {{CURRENT_BEHAVIOR}} |
| **Expected** | {{EXPECTED_BEHAVIOR}} |
| **Impact** | {{USER_OR_SYSTEM_IMPACT}} (severity: {{SEVERITY}}) |

**Repro:** {{REPRO_STEP_1}} → {{REPRO_STEP_2}} → {{REPRO_STEP_3}} — **env:** {{ENV_DETAILS}} — **freq:** {{HOW_OFTEN}}

## Root cause

{{ROOT_CAUSE_OR_INVESTIGATION_NOTES}} — **if unknown:** {{HYPOTHESIS}} — **evidence:** {{EVIDENCE_LINKS_OR_NOTES}}

## Fix approach

{{PROPOSED_FIX_SUMMARY}} — **risk:** {{RISK_NOTES}}

- [ ] {{FIX_TASK_1}}
- [ ] {{FIX_TASK_2}}

## Test plan

- [ ] Verify: {{VERIFY_STEPS}} — regressions: {{REGRESSION_AREAS}} — monitoring: {{MONITORING_NOTES}}

## Prevention

{{CAUSE_CATEGORY}} — {{PREVENTION_ACTIONS}} (owner {{OWNER}}, by {{DATE}})
