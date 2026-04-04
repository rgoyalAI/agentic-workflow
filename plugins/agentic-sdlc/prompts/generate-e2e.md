# Prompt Template: GenerateE2E Agent

Use for **end-to-end** test generation across UI and/or API. Replace `{{placeholders}}`. Integrate **accessibility** checks per `standards/ui/accessibility-checklist.md` where UI is involved.

---

## Inputs

- **Story ID:** `{{story_id}}`
- **Critical user journeys:** {{numbered_list}}
- **Environment:** `{{base_url}}` | staging | local
- **Auth:** {{fixture_user_or_token_strategy}}
- **Browsers / channels:** {{chromium_webkit_firefox}}
- **Test runner:** {{playwright_cypress_selenium}}
- **Data:** {{seed_commands_or_api_fixtures}}

---

## Instructions

1. **Scope**
   - Cover **primary** flows for the story; avoid duplicating entire regression suite unless asked.
   - Tag tests with `@story:{{story_id}}` or equivalent for traceability.

2. **Stability**
   - Use **role-based selectors** (`data-testid` contract) — avoid brittle CSS/XPath tied to styling.
   - **Wait** for network/idle states explicitly; no fixed `sleep` except rare cases with comment rationale.

3. **Accessibility**
   - Run **axe** (or equivalent) on critical pages after navigation and after modal open.
   - Fail on **serious/critical** violations unless documented waiver.

4. **Assertions**
   - Assert **user-visible outcomes** (text, URL, persisted state via API check if needed).
   - Capture **screenshots/video** on failure per runner config.

5. **Artifacts**
   - Test files under agreed folder (`e2e/`, `tests/e2e/`, etc.).
   - Results file path for orchestrator: e.g. `./context/{{story_id}}/e2e-results.json` if required.

6. **Secrets**
   - Never commit tokens; read from CI secrets or local env templates.

---

## Output checklist

- [ ] Journeys trace to story AC
- [ ] axe policy stated and executed
- [ ] Results artifact path recorded
- [ ] Flake risks called out (timers, third-party widgets)

---

## A2A envelope fields

- `acceptance_criteria`: AC covered; axe policy stated; results file present
- `artifacts`: e2e spec paths + results path
