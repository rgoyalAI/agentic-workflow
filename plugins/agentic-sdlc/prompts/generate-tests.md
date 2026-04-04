# Prompt Template: GenerateTests Agent

Use for **unit** and **integration** test generation from acceptance criteria. Replace `{{placeholders}}`. Follow testing strategy in `AGENTS.md`: deterministic tests, error paths, naming aligned with repo conventions.

---

## Inputs

- **Story ID:** `{{story_id}}`
- **Acceptance criteria (verbatim):**  
  {{acceptance_criteria_list}}
- **Code paths / modules in scope:** {{paths}}
- **Language & framework:** {{language}} / {{framework}}
- **Test stack:** {{pytest_jest_xunit_etc}}
- **Coverage threshold:** {{threshold}}
- **Forbidden:** {{no_network_no_external_calls_unless_noted}}

---

## Instructions

1. **Map AC → tests**
   - For **each** acceptance criterion, define at least **one** automated test (or justify explicit manual test with steps).
   - Include **happy path** and **representative error/edge** cases per module.

2. **Design**
   - Prefer **pure unit tests** for logic; **integration tests** for DB/HTTP boundaries with Testcontainers or approved test doubles.
   - Use **factories/builders** for data; avoid hard-coded magic numbers without meaning.

3. **Implementation**
   - Match existing **file layout**, **import style**, and **assertion** libraries in the repo.
   - Name tests so failures read as specs (`should_<behavior>_when_<condition>` or equivalent local convention).

4. **Artifacts**
   - Emit `test-plan.md` using `templates/test-plan.md` filled with AC mapping.
   - List new/changed test file paths explicitly.

5. **Security**
   - No real credentials; use env fixtures or mocks.
   - Do not log secrets in test output.

---

## Output checklist

- [ ] One or more tests per AC (or documented exception)
- [ ] Error path covered where AC implies failure modes
- [ ] Tests are **deterministic** (no flaky time/network without control)
- [ ] `test-plan.md` AC table complete

---

## A2A envelope fields

- `artifacts`: test file paths + `test-plan.md`
- `acceptance_criteria`: minimum one test per AC; error paths; conventions matched
