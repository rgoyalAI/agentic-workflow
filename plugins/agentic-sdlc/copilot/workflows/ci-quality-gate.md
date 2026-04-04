# Workflow: CI quality gate (reference)

Use this **GitHub Actions** template to enforce a minimal **quality gate** on pull requests: checkout, setup language tooling as needed, **build**, **test**, and optional **coverage threshold** check.

## Installation

Copy the YAML below to **`.github/workflows/ci-quality-gate.yml`**. Adjust `on.branches`, toolchains, and coverage tooling for your stack (JaCoCo, pytest-cov, dotnet-coverage, etc.).

## Workflow: `ci-quality-gate.yml`

```yaml
name: ci-quality-gate

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]

permissions:
  contents: read
  pull-requests: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-test:
    name: Build and test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # --- Replace with your stack setup (examples) ---
      # - uses: actions/setup-java@v4
      #   with:
      #     distribution: temurin
      #     java-version: "17"
      # - name: Test (Maven)
      #   run: mvn -B test

      # - uses: actions/setup-node@v4
      #   with:
      #     node-version: "20"
      #     cache: npm
      # - run: npm ci
      # - run: npm test -- --ci

      - name: Placeholder — configure your build
        run: |
          echo "Replace this step with your build and test commands."
          echo "Fail the job on compile or test failure."

  coverage:
    name: Coverage gate (optional)
    runs-on: ubuntu-latest
    needs: [build-test]
    if: ${{ success() }}
    steps:
      - uses: actions/checkout@v4

      - name: Coverage placeholder
        run: |
          echo "Parse coverage.xml / lcov.info / cobertura and fail if below threshold."
          echo "Or upload to codecov/sonar and gate on their checks."

      # Example: fail if no coverage artifact in strict mode
      # - name: Enforce coverage file exists
      #   run: test -f coverage/lcov.info
```

## Quality rubric alignment

Map job results to **`./context/quality-gate-report.md`** fields used by the Agentic SDLC plugin:

| Gate | CI signal |
|------|-----------|
| Build | `build-test` success |
| Tests | test step exit 0 |
| Coverage | dedicated step or external app check |
| Security | Add CodeQL, Dependabot, or SARIF upload job |

## Branch protection

Enable **required status checks** for `ci-quality-gate` / `build-test` on protected branches so merges match the same bar as the **quality-gate** agent rubric.
