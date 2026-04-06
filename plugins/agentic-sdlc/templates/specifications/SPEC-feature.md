<!--
How to use: Fill this before DecomposeRequirements / planning. Replace {{PLACEHOLDER}}
values; keep Must Have tight; use Gherkin for acceptance criteria the team can test.
-->

# Feature specification — {{FEATURE_ID_OR_NAME}}
## Overview

**Problem:** {{PROBLEM_STATEMENT}} — **Solution:** {{PROPOSED_SOLUTION_SUMMARY}} — **Impact:** {{USER_OR_BUSINESS_IMPACT}}

## User story

As a **{{PERSONA}}**, I want **{{CAPABILITY}}**, so that **{{BENEFIT}}**.

## Requirements

### Must have

- [ ] {{MUST_HAVE_1}}
- [ ] {{MUST_HAVE_2}}
- [ ] {{MUST_HAVE_3}}

### Nice to have

- [ ] {{NICE_TO_HAVE_1}}
- [ ] {{NICE_TO_HAVE_2}}

## Technical constraints

| Type          | Constraint / notes                                              |
| ------------- | --------------------------------------------------------------- |
| Performance   | {{PERF_CONSTRAINT}} — {{PERF_NOTES}}                            |
| Security      | {{SECURITY_CONSTRAINT}} — {{SECURITY_NOTES}}                  |
| Compatibility | {{COMPAT_CONSTRAINT}} — {{COMPAT_NOTES}}                      |

## Acceptance criteria (Gherkin)

```gherkin
Feature: {{FEATURE_TITLE_FOR_GHERKIN}}
  Scenario: {{HAPPY_PATH_TITLE}}
    Given {{GIVEN_CONTEXT}}
    When {{WHEN_ACTION}}
    Then {{THEN_OUTCOME}}
  Scenario: {{EDGE_OR_ERROR_TITLE}}
    Given {{GIVEN_EDGE_CONTEXT}}
    When {{WHEN_EDGE_ACTION}}
    Then {{THEN_EDGE_OUTCOME}}
```

## Success metrics

| Metric       | Baseline → target | Measured by        |
| ------------ | ----------------- | ------------------ |
| {{METRIC_1}} | {{BASELINE_1}} → {{TARGET_1}} | {{MEASUREMENT_1}} |
| {{METRIC_2}} | {{BASELINE_2}} → {{TARGET_2}} | {{MEASUREMENT_2}} |

## Out of scope

- {{OUT_OF_SCOPE_1}}
- {{OUT_OF_SCOPE_2}}
