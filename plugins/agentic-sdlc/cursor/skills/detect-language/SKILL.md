---
name: detect-language
description: Detects the project language and framework by scanning project files. Returns the detected language, framework, and paths to relevant best practice files. Supports Java (Spring Boot, Quarkus), Python (FastAPI, Django, Flask), .NET, Go (stdlib, Gin, Echo), React, and Angular.
---

# Detect Language

## Purpose

Provide a **deterministic, file-evidence-based** profile of the workspace: primary language(s), dominant framework(s), and pointers to **best-practice references** so test, coverage, and implementation agents use the correct toolchain—especially in **monorepos** with multiple stacks.

## Algorithm / Operations

### Pass 1 — Language detection (priority order; first strong match wins per subtree)

Scan from the repository root (respect nested packages as separate roots when obvious):

1. **Java**: `pom.xml`, `build.gradle`, `build.gradle.kts`, or any `**/*.java`
2. **Python**: `pyproject.toml`, `requirements*.txt`, or any `**/*.py`
3. **.NET**: `*.csproj`, `global.json`, or any `**/*.cs`
4. **Go**: `go.mod` or any `**/*.go`
5. **React**: `package.json` listing `"react"` as a dependency, plus `**/*.tsx` / `**/*.jsx`
6. **Angular**: `package.json` listing `"@angular/core"`, plus `angular.json`

Record **multiple languages** when multiple independent roots exist (monorepo), each with its root path.

### Pass 2 — Framework detection (dependency files)

- **Java**
  - `spring-boot-starter*` / Spring Boot BOM → **Spring Boot**
  - `io.quarkus` / Quarkus BOM → **Quarkus**
  - Else: **JVM library/service** (unspecified framework)

- **Python** (from `pyproject.toml` / `requirements*.txt`)
  - `fastapi` → **FastAPI**
  - `django` → **Django**
  - `flask` → **Flask**

- **Go** (from `go.mod`)
  - `github.com/gin-gonic/gin` → **Gin**
  - `github.com/labstack/echo` → **Echo**
  - Else → **stdlib** (or minimal router if detected)

- **Frontend** (from `package.json`)
  - React vs Angular already gated in Pass 1; capture version major if useful for tooling.

### Best-practice file resolution

Map detected stack to repo-local or org-standard docs (if present), e.g. `./contexts/java.md`, `./docs/CONTRIBUTING.md`, or framework-specific guides—only include paths that **exist**.

### Command inference

Derive typical **build**, **test**, and **coverage** commands from the stack (see `run-tests` / `validate-coverage` skills); when ambiguous, prefer the least surprising default and note assumptions.

## Input

- Workspace root path.
- Optional: subdirectory scope for a single package in a monorepo.

## Output

JSON document (stdout or `./context/language-profile.json` if the pipeline expects a file):

```json
{
  "language": "java | python | dotnet | go | react | angular | multi",
  "framework": "string",
  "roots": [{ "path": ".", "language": "java", "framework": "spring-boot" }],
  "best_practice_files": ["existing-paths-only"],
  "build_cmd": "string",
  "test_cmd": "string",
  "coverage_cmd": "string"
}
```

## Safety

- **Never** guess languages from filenames alone when manifests contradict (e.g., stray `.java` in a Python repo)—prefer manifests and dependency graphs.
- Do not execute arbitrary scripts discovered during detection; only **read** files.
- If detection is inconclusive, set `language` to `unknown` or use `multi` with per-root entries—downstream agents must not assume a single global framework.
