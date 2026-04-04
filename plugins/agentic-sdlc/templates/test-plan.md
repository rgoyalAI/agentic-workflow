# Test Plan — Story `{{story_id}}`

## Scope

**Story title:** {{story_title}}  
**Risk level:** `Low` | `Medium` | `High`  
**In scope:** {{brief_scope}}  
**Out of scope:** {{explicit_non_goals}}

---

## Test types

| Type | Run where | Purpose |
|------|-----------|---------|
| **Unit** | CI on every commit | Fast feedback; pure logic, mappers, validators |
| **Integration** | CI on PR / nightly | DB, queue, HTTP with Testcontainers or env |
| **E2E** | Staging / pre-release | Critical user journeys, cross-service flows |

---

## Test files (planned or added)

| File path | Type | Notes |
|-----------|------|-------|
| {{path_1}} | unit / integration / e2e | |
| {{path_2}} | | |

---

## Coverage targets

| Layer | Target | Tooling |
|-------|--------|---------|
| Lines | {{line_pct}}% | {{tool}} |
| Branches | {{branch_pct}}% | {{tool}} |
| Critical modules | {{modules}} | explicit list |

**Exclusions (documented):** {{generated_code_paths_or_boilerplate}}

---

## Acceptance criteria mapping

Map each **AC** from the story to at least one automated test (or explicit manual script with owner).

| AC # | Acceptance criterion (summary) | Test case ID / file | Automated? |
|------|--------------------------------|----------------------|------------|
| 1 | | | yes / no |
| 2 | | | |

---

## Test data

- **Fixtures:** {{fixtures}}
- **PII:** {{none_or_synthetic_only}}

---

## Exit criteria

- [ ] All **must-have** tests implemented and **passing**
- [ ] Coverage meets **threshold** or **waiver** documented
- [ ] **E2E** smoke for {{critical_paths}} if applicable
- [ ] **Flaky** tests tracked with issue IDs
