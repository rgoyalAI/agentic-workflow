# CI/CD Pipeline Integration

This guide explains how to run **agentic-sdlc** quality expectations in **continuous integration**, separate **deterministic** checks from **AI-augmented** reviews, provide **GitHub Actions** and **Azure DevOps** patterns, define **merge gates**, and configure **CI mode** vs **IDE mode**.

---

## Goals

- **Same bar for quality** in CI as in local runs: compile, test, coverage, lint, vulnerability scan, and (optionally) gated human or bot review.  
- **Fast feedback:** deterministic jobs first; expensive or LLM-based steps optional or scheduled.  
- **Deterministic artifacts:** `test-results.json`, `coverage.json`, JUnit XML, SARIF — so QualityGate logic can be reused or mirrored in CI.

---

## Deterministic vs AI-augmented

| Category | Examples | Typical location |
|----------|----------|------------------|
| **Deterministic** | Compile, unit/integration tests, coverage thresholds (≥ 80%), linters, format check, dependency audit, container scan, secret scan | CI always-on |
| **AI-augmented** | Code review agent, architecture review agent, security narrative review, doc generation | IDE or async CI job / manual |

**Rule of thumb:** Anything that must block merge should have a **scriptable** check in CI. AI agents **add** signal; they should not be the only line of defense for security or coverage.

---

## Running quality gates in CI

### GitHub Actions

1. **Checkout** with fetch depth sufficient for diffs if you compare against base.  
2. **Setup** language runtime (Java, Node, Python, .NET, etc.) with pinned versions.  
3. **Cache** dependencies (Maven, Gradle, npm, pip, NuGet).  
4. **Build** — `mvn -q compile`, `dotnet build`, etc.  
5. **Test** — `mvn test`, `pytest`, `npm test` with CI=true.  
6. **Coverage** — JaCoCo, Coverlet, Istanbul/c8, pytest-cov; **fail** if below threshold.  
7. **Lint / format** — Checkstyle, SpotBugs, ESLint, Ruff, dotnet format.  
8. **Security** — `npm audit`, OWASP dependency-check, Trivy on images, GitHub Dependency review.  
9. **Publish** — Upload JUnit XML, coverage reports, SARIF to Code Scanning.

### Azure DevOps

Use **multi-stage YAML pipelines** with the same steps: `Restore` → `Build` → `Test` with `--collect:"XPlat Code Coverage"` → `PublishCodeCoverageResults` → `PublishTestResults`. Add **SonarQube** or **Microsoft Defender for DevOps** tasks if your org uses them.

---

## GitHub Actions workflow example

Below is a **minimal** pattern; adjust matrix, Java version, and commands to your repo.

```yaml
name: quality-gate

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main, develop ]

jobs:
  deterministic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "21"
          cache: maven

      - name: Compile and test
        run: mvn -q -B verify

      - name: Enforce coverage (example: parse JaCoCo or fail build in pom)
        run: mvn -q jacoco:check

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: surefire-reports
          path: target/surefire-reports/
```

Add **paths filters** so documentation-only PRs skip heavy jobs.

---

## Merge gate requirements

A typical **merge gate** includes:

1. **Required status checks** — CI green on branch protection.  
2. **Coverage** — ≥ 80% line (or org policy) on changed code or whole project.  
3. **No high/critical** dependency or container findings (per policy).  
4. **Reviews** — At least one human approval for production branches; optional AI summary as non-blocking comment.  
5. **Up to date with base** — Rebase or merge main before merge when required.

---

## Self-review pattern

Before opening a PR, contributors run the same scripts locally or via **act** / **pre-push hooks**:

- Format and lint auto-fix where safe.  
- Full test + coverage.  
- Optional: run Cursor agent **ReviewCode** on changed files and paste summary into PR description.

This mirrors **IDE mode** behavior without requiring CI to invoke LLMs.

---

## CI mode vs IDE mode

| Aspect | CI mode | IDE mode |
|--------|---------|----------|
| **Orchestration** | Scripts, pipelines, branch protection | OrchestrateSDLC agent, `@` agents |
| **Reviews** | Human + optional async bot | Parallel ReviewCode / ReviewArchitecture / ReviewSecurity |
| **Context** | Env vars, artifacts, checkout | `./context/`, `./memory/`, skills |
| **Retries** | Re-run failed job; fix and push | Retry loop to ImplementCode with tags |
| **Secrets** | GitHub/Azure secrets, OIDC | Local env; never commit |

**Configuration:** Use environment variables such as `SDLC_MODE=ci` vs `SDLC_MODE=ide` in your wrapper scripts so shared tools skip interactive prompts and write only to CI-safe paths.

---

## References

- Full pipeline: `workflows/full-sdlc.md`  
- Retry behavior: `workflows/retry-loop.md`  
- Example schemas: `contexts/stories.json`, `contexts/test-results.json`  
