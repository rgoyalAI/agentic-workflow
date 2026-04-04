# Package Structure and Dependency Management

This document defines how dependencies MUST be declared, locked, audited, and organized by language ecosystem. Goals: **reproducible builds**, **supply chain transparency**, and **clear module boundaries**.

---

## Universal principles

1. **Pin all dependency versions** in lockfiles or equivalent; never use floating ranges (`*`, `latest`, unbounded semver) for production artifacts.
2. **Use lockfiles** appropriate to the ecosystem and **commit them** to version control so CI and production resolve identical graphs.
3. **Prefer well-maintained, audited libraries** over custom crypto, parsing, or protocol implementations unless formally justified and reviewed.
4. **Run vulnerability scanning** in CI: `npm audit`, `pip-audit`, `mvn dependency:analyze`, `go mod verify`, `dotnet list package --vulnerable`, etc.
5. **Separate production and development dependencies** so production images and bundles exclude test tooling, linters, and dev-only packages unless required at runtime.

---

## Per-ecosystem reference

| Language | Lockfile | Pin Strategy | Supply Chain Safety |
|----------|----------|-------------|---------------------|
| Java (Maven) | `pom.xml` (explicit versions) + `maven-enforcer-plugin` | Exact versions in `<version>`, BOM for Spring | `maven-dependency-plugin:analyze`, `dependency-check-maven` (OWASP) |
| Java (Gradle) | `gradle.lockfile` | `gradle dependencies --write-locks` | `dependencyCheckAnalyze` plugin |
| Python | `poetry.lock` or `requirements.txt` (pinned with hashes) | `poetry lock` or `pip freeze > requirements.txt` | `pip-audit`, `safety check`, `bandit` |
| Go | `go.sum` (automatic) | `go mod tidy`, `go mod verify` | `govulncheck`, `go mod graph` |
| .NET | `packages.lock.json` | `<RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>` | `dotnet list package --vulnerable` |
| Node/React/Angular | `package-lock.json` or `pnpm-lock.yaml` | `npm ci` (not `npm install`) | `npm audit`, `socket.dev` |

---

## Package organization rules

### Java

- Prefer **feature-based packages** (`com.company.auth`, `com.company.order`) over purely layer-based trees (`com.company.controller`, `com.company.service`) when features are cohesive vertical slices.
- Keep **public API surface** small: expose factories or facades from a module root package if needed.
- Align package names with deployment units when using multi-module Maven/Gradle projects.

### Python

- **One module per concern**; avoid mega-modules that mix unrelated helpers.
- Use `__init__.py` to define the **public API** of a package; re-export stable names explicitly.
- Prefix **internal-only** modules with `_` (e.g., `_internal_cache.py`) to signal non-public contracts.

### Go

- Prefer **flat, focused packages** with a clear noun identity (`invoice`, `ledger`).
- Avoid **`utils` / `common` / `helpers`** grab-bags; split by behavior or domain.
- Keep **package comments** describing purpose; enforce cohesion—if two files do not share a reason to change, they may belong in different packages.

### .NET

- Use **feature folders** within **Clean Architecture** layers: `Domain`, `Application`, `Infrastructure`, `API` (or equivalent).
- Register dependencies in **composition roots** (e.g., `Program.cs`, `Startup`)—do not use service locator patterns in domain code.
- Keep **NuGet references** at the project that actually needs them; avoid transitive “just in case” references.

### Node / React / Angular

- **Colocate** tests and stories near components when the repo standard does so.
- Use **path aliases** (`@app/...`) consistently; avoid deep relative imports across feature boundaries.
- For Angular, follow **NgModule** or **standalone** patterns per project—do not mix strategies in the same feature without migration plan.

---

## CI and release gates

| Gate | Action |
|------|--------|
| On PR | Resolve lockfile; fail if lock out of date or vulnerable above policy threshold |
| On release | Re-verify checksums (`go mod verify`, `npm ci`) |
| Periodic | Run OWASP dependency-check or equivalent; track remediation SLAs |

---

## Anti-patterns

- Committing `node_modules` or `.venv` unless project explicitly requires it (generally avoid).
- **Dependency confusion**: always scope private registries and verify package provenance.
- **Pinning only in comments** while `package.json` still uses ranges—source of truth must be the lockfile + semver policy.

Agents MUST generate manifests with pinned versions and reference this document when adding dependencies.

---

## Semver and upgrade policy

- **Pin** exact versions in lockfiles; use **automation** (Renovate, Dependabot, Mend) for bump PRs—not manual `latest` installs.
- **Breaking changes**: major version upgrades require changelog review and targeted test runs; do not batch unrelated major bumps in one PR.
- **Transitive risk**: When a direct dependency is abandoned, prefer maintained forks or alternatives after security review.

---

## Private registries and monorepos

- Configure **scoped registries** (`@corp`, private PyPI, Azure Artifacts, Artifactory) explicitly in `.npmrc`, `pip.conf`, or `nuget.config`—never rely on ambiguous defaults.
- In **monorepos**, use workspace protocols (`workspace:*`) where supported; still record resolved versions in the lockfile at release boundaries.
- **Vendoring** (Go vendor/, checked-in third_party): document update procedure and license file obligations.

---

## SBOM and license compliance

- Generate **SBOM** artifacts (CycloneDX/SPDX) for release builds where organizational policy requires.
- Track **license allowlists** (MIT, Apache-2.0, BSD) and escalate **GPL/AGPL** in linked contexts to legal review.
- Record **attribution** notices for bundled dependencies in shipped products when required.

---

## Development-only dependencies

| Concern | Rule |
|---------|------|
| Test runners, linters, formatters | `devDependencies` (Node), optional Poetry groups, `test` scope (Maven) |
| Production images | Multi-stage builds; prune dev deps in final stage |
| Runtime misuse | Never import test utilities from production modules |

---

## Troubleshooting lockfile drift

| Symptom | Action |
|---------|--------|
| CI fails “lockfile out of date” | Regenerate with the documented command; commit lockfile in same PR as manifest change |
| Conflicting peer deps | Resolve with explicit overrides only when justified; document in PR |
| Duplicate versions of same lib | Use dependency constraints or `resolutions` (Yarn) with care—verify bundle size |

---

## Review checklist (dependencies)

| # | Check |
|---|--------|
| D1 | Lockfile committed and consistent with manifest |
| D2 | No floating `*` / `latest` in production paths |
| D3 | Vulnerability scan policy addressed |
| D4 | New dependency justified (maintenance, license, footprint) |
| D5 | Prod vs dev separation preserved |

Dependency changes are **high-risk**: prefer minimal diffs and reproducible commands (`npm ci`, `poetry install --sync`).

---

## Overrides and resolutions (use sparingly)

| Ecosystem | Mechanism | Risk |
|-----------|-----------|------|
| npm | `overrides` | Hides upstream fix schedule—document end date |
| Yarn | `resolutions` | Same as above |
| pip | constraints files | Pin transitive for reproducibility |
| Maven | `<dependencyManagement>` | Centralize versions in BOM |

Review **quarterly** whether overrides can be removed after upstream releases.

---

## Internal packages

- **Version** internal shared libraries with semver; publish to private feed with **changelog**.
- **Breaking changes** require migration guides and coordinated consumer updates.
- Avoid **diamond dependency** conflicts by keeping shared libs thin and stable.

---

## Container images

- **Distroless** or minimal bases for production; pin image digests in deploy manifests when policy requires.
- **Scan images** (Trivy, Grype) in CI; fail on criticals per policy.

---

## Documentation requirements for new deps

Each new third-party dependency PR SHOULD include:

1. **Purpose** (one paragraph)
2. **License** and compatibility
3. **Maintenance** signal (last release, open issues)
4. **Footprint** (bundle size or transitive count for Node)

---

## Emergency patches

When a **critical CVE** forces an emergency upgrade:

- Prefer **minimal** version bump that contains the fix.
- Run **smoke + security** test suites; expedite review with explicit risk acceptance.

Operational excellence for dependencies means **predictable** upgrades, not heroic fire drills every quarter.
