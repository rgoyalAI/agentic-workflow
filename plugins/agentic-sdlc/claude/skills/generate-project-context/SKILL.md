---
name: generate-project-context
description: Scans the repo to auto-generate or update contexts/PROJECT_CONTEXT.md with tech stack, structure, and conventions. Run early in the SDLC pipeline or when onboarding a new project.
---

# Generate Project Context

## When to use

- First time the SDLC pipeline runs on a new project (orchestrator Phase 0)
- When `contexts/PROJECT_CONTEXT.md` is missing or contains only placeholder text
- After significant structural changes (new language, framework migration, major refactor)

## Steps

1. **Identify modules** — scan the repo for separate backend, frontend, shared-lib, and infrastructure roots. A module is any directory with its own build descriptor (pom.xml, package.json, pyproject.toml, *.csproj, go.mod, Cargo.toml, etc.). Monorepos may have many; single-stack repos have one.
2. **Detect language and framework per module** — for each module, record language, framework, build tool, and test framework from build descriptors per AGENTS.md §2.1. A project can have Java backend + TypeScript frontend, Python API + React SPA, etc.
3. **Detect domains** — check for API specs, database migrations, security modules per AGENTS.md §2.2.
4. **Scan repo structure** — list top-level directories and key config files (Dockerfile, CI workflows, README, AGENTS.md).
5. **Identify conventions** — check for linters (.eslintrc, ruff.toml, .editorconfig), packaging (Docker, Helm, Terraform), and CI/CD (.github/workflows, Jenkinsfile, azure-pipelines.yml).
6. **Read existing README** — extract project description, run commands, and test commands if available.
7. **Write `contexts/PROJECT_CONTEXT.md`** using the template below. Include one subsection per detected module under Tech Stack. Replace placeholders with detected values; use `unknown` for anything not verifiable from repo evidence.
8. **Validate** — confirm the file exists and contains no placeholder markers like `{{` or `TODO`.

## Template

```markdown
# Project Context — {project-name}

## What This Is
{One-sentence description from README or inferred from repo structure}

## Tech Stack

### Backend
- **Language**: {detected language} {version}
- **Framework**: {detected framework} {version}
- **Build tool**: {maven/gradle/pip/dotnet etc.}
- **Test framework**: {junit/pytest/xunit/go test etc.}

### Frontend
- **Language**: {detected language} {version}
- **Framework**: {detected framework} {version}
- **Build tool**: {npm/yarn/pnpm etc.}
- **Test framework**: {jest/vitest/playwright etc.}

### Data & Messaging
- **Database**: {postgres/mysql/mongo/none detected}
- **Cache**: {redis/memcached/none detected}
- **Message broker**: {kafka/rabbitmq/sqs/none detected}

### Infrastructure & CI/CD
- **Containerization**: {docker/podman/none detected}
- **Orchestration**: {kubernetes/ecs/none detected}
- **IaC**: {terraform/pulumi/cloudformation/none detected}
- **CI/CD**: {github-actions/jenkins/azure-pipelines/none detected}

> Omit any subsection (Backend, Frontend, Data, Infra) that does not apply.
> For monorepos with more modules (e.g., shared-lib, mobile, ML pipeline),
> add one subsection per module following the same pattern.

## Key Principles
{Copy from AGENTS.md §3 or project-specific overrides if found}

## Repository Structure
{Top-level directory tree with one-line purpose for each}

## How to Run
{Per-module commands from README or build files, or `unknown` if not found}

## How to Test
{Per-module test commands from README or build files, or `unknown` if not found}

## Critical Rules
{From AGENTS.md or project-specific rules}

## Pipeline Integration
- Governed by: `AGENTS.md`
- SDLC plugin: `plugins/agentic-sdlc/`
- Stories: `./context/stories.json`
```

## Output

Return the path to the generated file: `contexts/PROJECT_CONTEXT.md`.

## Safety

- Never include secrets, credentials, or environment-specific values in the output.
- Use only verifiable repo evidence — do not hallucinate versions, URLs, or service names.
- If a section cannot be filled, write `unknown — no repo evidence found` rather than guessing.
