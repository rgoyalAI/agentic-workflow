---
name: generate-e2e
description: Generates end-to-end test files from story acceptance criteria and UI touchpoints. For frontend: Playwright tests with accessibility checks (axe-core). For API: HTTP integration tests with full request/response validation.
---

# Generate E2E

## Purpose

Close the loop between **stories** and **executable verification** by generating **end-to-end tests** aligned with acceptance criteria: browser flows with **accessibility** checks for UI, and **HTTP-level** integration tests for APIs—then running them and recording outcomes for the quality gate.

## Algorithm / Operations

1. **Read inputs**
   - Current story acceptance criteria from `./context/stories.json` (or active story slice).
   - Implementation notes from `./context/implementation-log.md` (or agreed path) for URLs, routes, payloads, auth mode.

2. **Classify story type**
   - **Frontend**: labels/language imply UI (e.g., `react`, `angular`, `ui`), or AC references components/pages.
   - **API**: OpenAPI/route-based services, or AC centered on HTTP semantics and status codes.
   - **Mixed**: generate both layers with shared fixtures; order API-first if UI depends on seeded data.

3. **Frontend (Playwright)**
   - Generate **spec files** under the repo’s conventional E2E folder (e.g., `e2e/`, `tests/e2e/`), using **Page Objects** for stable selectors (`data-testid` preferred).
   - Encode **navigation**, **forms**, and **assertions** mapped 1:1 to Gherkin scenarios where possible.
   - Add **axe-core** scans on critical views (post-navigation, post-modal) with violations failing the test or surfacing structured results per team policy.

4. **API (HTTP integration)**
   - Generate tests using the stack’s HTTP client patterns (e.g., `requests`, `httpx`, `HttpClient`) or neutral `fetch` in Node.
   - Cover **happy paths** and key **error contracts** (401/403/404/422), including auth header flows if documented.

5. **Execute E2E suite**
   - Use project scripts (`npx playwright test`, package.json `test:e2e`, etc.).
   - Ensure services are reachable per session (base URL from env); if not, record `missing-data` instead of guessing ports.

6. **Write results** to `./context/e2e-results.json` with pass/fail counts, trace links (if enabled), and failure summaries.

## Input

- Story id / acceptance criteria text.
- Base URL(s), test users/roles (from secure env), feature flags.
- Optional: OpenAPI spec path for request/response schemas.

## Output

- **Test files** on disk (paths listed in the summary).
- **`./context/e2e-results.json`** (illustrative):

```json
{
  "framework": "playwright | http",
  "passed": 0,
  "failed": 0,
  "skipped": 0,
  "failures": [{ "test": "", "message": "", "file": "" }],
  "axe": { "violations": 0, "report_path": "optional" }
}
```

## Safety

- **Never** embed real credentials, API keys, or JWTs in generated tests—read from env and document required variables.
- Avoid **flaky** patterns: prefer role-based selectors and explicit waits over arbitrary `sleep`—if UI is not stable for automation, flag as `missing-data` / tech debt rather than shipping brittle tests.
- Accessibility: axe results can be noisy—configure **serious/critical** rules as blocking per policy; do not claim WCAG compliance from automated scans alone.
- For shared environments, ensure tests **isolate data** (unique ids) to prevent destructive collisions.
