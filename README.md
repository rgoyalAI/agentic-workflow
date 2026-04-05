# Agentic Workflow Framework

A governance and orchestration framework for **AI-assisted software development**. It provides rules, contexts, agents, skills, and multi-IDE plugins so AI coding assistants deliver **repeatable, auditable, enterprise-grade** results—from requirements to merge-ready pull requests.

---

## Table of Contents

- [Why This Framework](#why-this-framework)
- [Architecture Overview](#architecture-overview)
- [Repository Layout](#repository-layout)
- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
  - [Setup for Cursor](#setup-for-cursor)
  - [Setup for Claude Code](#setup-for-claude-code)
  - [Setup for GitHub Copilot (VS Code)](#setup-for-github-copilot-vs-code)
  - [Quick Reference: What to Copy](#quick-reference-what-to-copy)
- [Generating an Application (Testing the Framework)](#generating-an-application-testing-the-framework)
- [Plugins](#plugins)
- [Contexts](#contexts)
- [Skills](#skills)
- [Multi-IDE Support](#multi-ide-support)
- [MCP Integrations](#mcp-integrations)
- [Standards Library](#standards-library)
- [Deployment Templates](#deployment-templates)
- [Configuration](#configuration)
- [Contributing](#contributing)

---

## Why This Framework

Traditional AI coding assistants are single-threaded and session-fragile: they lose scope, skip verification, and struggle with multi-step delivery. This framework solves that by encoding:

- **`AGENTS.md` as a constitution** — a single source of truth that every AI agent must follow
- **Deterministic context loading** — agents detect project signals (language, API, database, security) and load only the relevant context files
- **Orchestrator + stateless specialists** — an orchestrator plans and delegates; specialists (implementer, reviewer, tester, security auditor) do focused work with explicit quality gates
- **Enterprise guardrails** — retry limits, token budgets, human-in-the-loop escalation, and OWASP security checks built in

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     AGENTS.md                           │
│            (Single source of truth)                     │
├────────────┬────────────┬───────────────────────────────┤
│  contexts/ │  .cursor/  │  .claude/                     │
│  (language │  (rules,   │  (rules, skills,              │
│   + domain │   skills,  │   agents, hooks)              │
│   contexts)│   agents,  │                               │
│            │   hooks)   │                               │
├────────────┴────────────┴───────────────────────────────┤
│                      plugins/                           │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────────────┐│
│  │   adm    │ │  security-   │ │   agentic-sdlc       ││
│  │          │ │  governance  │ │   (16 agents, 13     ││
│  │          │ │              │ │    skills, standards, ││
│  │          │ │              │ │    deployment)        ││
│  └──────────┘ └──────────────┘ └──────────────────────┘│
│  ┌──────────────────────┐                               │
│  │   test-generation    │                               │
│  └──────────────────────┘                               │
└─────────────────────────────────────────────────────────┘
```

**Orchestration model:**

1. **OrchestrateSDLC** receives a requirement (free text or Jira ID)
2. **DecomposeRequirements** breaks it into stories with dependency edges
3. Per story: **Plan → Design → Implement → Review → Test → E2E/Docs/Deploy → Quality Gate → Complete**
4. On failure: retry up to 3 times, then escalate to human
5. On success: open PR with linked artifacts

---

## Repository Layout

```
agentic-workflow/
├── AGENTS.md                          # Constitution for all AI agents
├── CLAUDE.md                          # Wrapper pointing to AGENTS.md
├── README.md                          # This file
│
├── contexts/                          # Language and domain contexts
│   ├── java.md                        # Java conventions (JUnit 5, Maven/Gradle)
│   ├── python.md                      # Python conventions (pytest, pyproject)
│   ├── dotnet.md                      # .NET conventions (xUnit, MSTest)
│   ├── api-design.md                  # REST/GraphQL validation, error envelopes
│   ├── database.md                    # Migrations, parameterized queries
│   └── security.md                    # Auth, secrets, OWASP patterns
│
├── .cursor/                           # Cursor IDE integration
│   ├── agents/                        # Cursor agent definitions
│   ├── skills/                        # Cursor skills
│   ├── rules/                         # Auto-applied rules (.mdc files)
│   └── hooks/                         # Lifecycle hooks (PowerShell/bash)
│
├── .claude/                           # Claude Code integration
│   ├── agents/                        # Claude agent definitions
│   ├── skills/                        # Claude skills
│   ├── rules/                         # Claude rules
│   └── settings.json                  # Hook configuration
│
├── .cursor-plugin/
│   └── marketplace.json               # Local plugin registry
│
└── plugins/                           # Multi-IDE plugin packages
    ├── README.md                      # Plugin overview and install guide
    ├── adm/                           # Agentic Development Management
    ├── agentic-sdlc/                  # Full SDLC pipeline (flagship)
    │   ├── cursor/agents/             # 16 specialist agent definitions
    │   ├── cursor/skills/             # 13 reusable skills
    │   ├── claude/                    # Claude Code package
    │   ├── copilot/                   # GitHub Copilot adapter
    │   ├── standards/                 # Coding, API, DB, security, UI, deployment
    │   ├── deployment-templates/      # Docker, K8s, Helm, CI/CD
    │   ├── workflows/                 # SDLC lifecycle documentation
    │   ├── observability/             # Trace schema, token budgets
    │   ├── memory/                    # Session root template
    │   └── templates/                 # Memory logs, quality gate, delegation
    ├── security-governance/           # Security rules and agents
    └── test-generation/               # Test planning and generation
```

---

## How It Works

### 1. Deterministic Context Loading

When an agent starts, it follows `AGENTS.md` Section 2 to detect project signals:

| Signal | Detection | Context Loaded |
|--------|-----------|----------------|
| **Java** | `pom.xml`, `build.gradle`, `*.java` | `contexts/java.md` |
| **Python** | `pyproject.toml`, `requirements*.txt`, `*.py` | `contexts/python.md` |
| **.NET** | `*.csproj`, `global.json`, `*.cs` | `contexts/dotnet.md` |
| **API** | `openapi*.yml`, `swagger*.json`, `*.graphql` | `contexts/api-design.md` |
| **Database** | `*.sql`, `migrations/`, `schema.prisma` | `contexts/database.md` |
| **Security** | `**/security/**`, `**/auth/**`, `jwt`, `oauth` | `contexts/security.md` |

### 2. Agent Orchestration

The **OrchestrateSDLC** agent delegates to 15 specialists:

| Phase | Agent(s) | Output |
|-------|----------|--------|
| Decompose | DecomposeRequirements | `stories.json` |
| Plan | PlanStory | `plan.md` per story |
| Design | DesignArchitecture | Architecture decisions |
| Implement | ImplementCode | Application code + tests |
| Review | ReviewCode, ReviewArchitecture, ReviewSecurity | Findings (parallel) |
| Test | GenerateTests, RunTests, ValidateCoverage | `test-results.json` |
| E2E/Docs/Deploy | GenerateE2E, UpdateDocumentation, GenerateDeployment | E2E tests, README, Dockerfile/Helm |
| Gate | QualityGate | `quality-gate-report.md` |
| Complete | CompleteStory | PR + Jira update |

### 3. Quality Gates

Every story must pass criteria including:
- All tests green
- Coverage >= 80% (configurable)
- No unresolved security findings
- Architecture review passed
- Documentation updated

### 4. Inter-Agent Communication (A2A)

Agents communicate via structured envelopes:

```text
A2A:
intent: <what to do>
assumptions: <what you are assuming>
constraints: <what you must obey>
loaded_context: <list of contexts actually loaded>
proposed_plan: <steps with ordering>
artifacts: <files or outputs to produce>
acceptance_criteria: <measurable pass/fail checks>
open_questions: <only if required>
```

---

## Quick Start

### Prerequisites

- **Cursor**, **Claude Code**, or **GitHub Copilot** (VS Code) IDE
- Git installed and available on PATH
- (Optional) Jira/GitHub MCP servers configured for ticket integration

### Clone the Framework

```bash
git clone <repo-url> agentic-workflow
```

---

### Setup for Cursor

Cursor uses `.cursor/` for agents, skills, rules (`.mdc` files), and hooks. It also reads `AGENTS.md` and `CLAUDE.md` from the project root.

#### Option A: Framework as workspace root (for framework development)

Open `agentic-workflow/` directly in Cursor — everything is already wired up.

#### Option B: Set up a new application project

```bash
mkdir my-app && cd my-app && git init

# 1. Copy the governance constitution and context wrapper
cp /path/to/agentic-workflow/AGENTS.md .
cp /path/to/agentic-workflow/CLAUDE.md .

# 2. Copy language and domain contexts
cp -r /path/to/agentic-workflow/contexts/ ./contexts/

# 3. Copy Cursor IDE integration (agents, skills, rules, hooks)
mkdir -p .cursor
cp -r /path/to/agentic-workflow/.cursor/agents/    .cursor/agents/
cp -r /path/to/agentic-workflow/.cursor/skills/    .cursor/skills/
cp -r /path/to/agentic-workflow/.cursor/rules/     .cursor/rules/
cp -r /path/to/agentic-workflow/.cursor/hooks/     .cursor/hooks/
cp    /path/to/agentic-workflow/.cursor/hooks.json .cursor/hooks.json

# 4. (Optional) Install the agentic-sdlc plugin for full SDLC pipeline
mkdir -p .cursor-plugins/agentic-sdlc
cp -r /path/to/agentic-workflow/plugins/agentic-sdlc/cursor/* .cursor-plugins/agentic-sdlc/
```

#### What you get

| Directory | Contents |
|-----------|----------|
| `.cursor/agents/` | 4 base agents (planner, implementer, verifier, security-auditor) |
| `.cursor/skills/` | 4 skills (load-contexts, draft-plan, generate-tests, security-check) |
| `.cursor/rules/` | Auto-applied rules for standards enforcement (`.mdc` files) |
| `.cursor/hooks/` | Lifecycle hooks (PowerShell/bash) for guardrails |
| `.cursor-plugins/agentic-sdlc/` | 16 specialist agents, 13 skills, MCP config, SDLC rules |

#### Verify the setup

Open the project in Cursor, switch to **Agent mode**, and run:

```text
@planner "Review the project structure and confirm AGENTS.md is loaded"
```

Or invoke the full SDLC pipeline (requires the agentic-sdlc plugin):

```text
@OrchestrateSDLC "Build a hello-world REST API with health check endpoint"
```

---

### Setup for Claude Code

Claude Code uses `.claude/` for agents, skills, rules, hooks, and `settings.json`. It reads `CLAUDE.md` from the project root (which points to `AGENTS.md`).

```bash
mkdir my-app && cd my-app && git init

# 1. Copy the governance constitution and Claude wrapper
cp /path/to/agentic-workflow/AGENTS.md .
cp /path/to/agentic-workflow/CLAUDE.md .

# 2. Copy language and domain contexts
cp -r /path/to/agentic-workflow/contexts/ ./contexts/

# 3. Copy Claude Code IDE integration (agents, skills, rules, hooks, settings)
mkdir -p .claude
cp -r /path/to/agentic-workflow/.claude/agents/      .claude/agents/
cp -r /path/to/agentic-workflow/.claude/skills/       .claude/skills/
cp -r /path/to/agentic-workflow/.claude/rules/        .claude/rules/
cp -r /path/to/agentic-workflow/.claude/hooks/        .claude/hooks/
cp    /path/to/agentic-workflow/.claude/settings.json .claude/settings.json

# 4. (Optional) Install the agentic-sdlc plugin for full SDLC pipeline
mkdir -p .claude-plugins/agentic-sdlc
cp -r /path/to/agentic-workflow/plugins/agentic-sdlc/claude/* .claude-plugins/agentic-sdlc/
```

#### What you get

| Directory | Contents |
|-----------|----------|
| `.claude/agents/` | 4 base agents (orchestrator, implementer, verifier, security-auditor) |
| `.claude/skills/` | 4 skills (load-contexts, draft-plan, generate-tests, security-audit) |
| `.claude/rules/` | Context rules for language and domain detection |
| `.claude/hooks/` | Hook scripts for guardrails (e.g., `audit-edit.ps1`) |
| `.claude/settings.json` | Hook configuration and Claude Code settings |
| `.claude-plugins/agentic-sdlc/` | 16 agents, 4 skills, MCP config, hooks, CLAUDE.md |

#### Verify the setup

Open the project in Claude Code and run:

```text
/agents
```

You should see the available agents listed. Then test with:

```text
Use the orchestrator agent to review the project structure and confirm AGENTS.md is loaded.
```

---

### Setup for GitHub Copilot (VS Code)

GitHub Copilot uses `.github/copilot-instructions.md` for global instructions and `.github/agents/` for agent prompt files. Copilot does not have a native multi-agent runtime, so you act as the orchestrator and invoke agents one phase at a time.

```bash
mkdir my-app && cd my-app && git init

# 1. Copy the governance constitution
cp /path/to/agentic-workflow/AGENTS.md .

# 2. Copy language and domain contexts
cp -r /path/to/agentic-workflow/contexts/ ./contexts/

# 3. Copy Copilot instructions and agents
mkdir -p .github/agents
cp /path/to/agentic-workflow/plugins/agentic-sdlc/copilot/copilot-instructions.md .github/copilot-instructions.md
cp /path/to/agentic-workflow/plugins/agentic-sdlc/copilot/agents/*.agent.md       .github/agents/

# 4. (Optional) Copy CI workflow templates
mkdir -p .github/workflows
# Review and copy the YAML blocks from the workflow markdown files:
# - plugins/agentic-sdlc/copilot/workflows/agentic-sdlc.md
# - plugins/agentic-sdlc/copilot/workflows/ci-quality-gate.md
```

#### What you get

| Directory | Contents |
|-----------|----------|
| `.github/copilot-instructions.md` | Global instructions pointing to `AGENTS.md` |
| `.github/agents/` | 10 agent prompt files (orchestrator, architect, test-generator, etc.) |
| `.github/workflows/` | CI workflow templates for quality gates |

#### How to use agents in Copilot Chat

Copilot agents are used as **structured system prompts** — not separate processes:

1. Open **Copilot Chat** in VS Code (or on GitHub.com).
2. Use **@workspace** so Copilot can read `AGENTS.md` and your contexts.
3. Reference the agent file and state your task:

```text
Follow the orchestrator agent definition in .github/agents/orchestrator.agent.md.
Decompose this requirement into stories: "Build a task management API with authentication"
```

4. For full pipelines, split into phases — one chat thread per phase with explicit handoff summaries:
   - **Phase 1:** Decomposition (use `requirement-decomposer.agent.md`)
   - **Phase 2:** Planning (use `orchestrator.agent.md` with decomposed stories)
   - **Phase 3:** Implementation (paste plan summary, use `orchestrator.agent.md`)
   - **Phase 4:** Review and testing (use `test-generator.agent.md`, `quality-gate.agent.md`)

#### Copilot limitations vs Cursor / Claude Code

| Aspect | Cursor / Claude Code | GitHub Copilot |
|--------|----------------------|----------------|
| Multi-agent runtime | Orchestrator delegates automatically | Manual; you play orchestrator |
| Session state | Managed via `sdlc-session.json` | You persist and paste summaries |
| Hooks / guardrails | IDE-enforced hooks | Rely on branch protection and CI |
| MCP integration | Configured in IDE | Use GitHub UI or Actions |
| Long-running retries | Scripted loops | Manual or custom Actions |

---

### Quick Reference: What to Copy

| File/Directory | Cursor | Claude Code | GitHub Copilot | Purpose |
|----------------|:------:|:-----------:|:--------------:|---------|
| `AGENTS.md` | Required | Required | Required | Constitution for all agents |
| `CLAUDE.md` | Required | Required | -- | Wrapper pointing to AGENTS.md |
| `contexts/` | Required | Required | Required | Language and domain contexts |
| `.cursor/` | Required | -- | -- | Cursor agents, skills, rules, hooks |
| `.claude/` | -- | Required | -- | Claude agents, skills, rules, settings |
| `.github/copilot-instructions.md` | -- | -- | Required | Copilot global instructions |
| `.github/agents/` | -- | -- | Required | Copilot agent prompt files |
| `plugins/agentic-sdlc/<ide>/` | Optional | Optional | Optional | Full SDLC pipeline plugin |

---

## Generating an Application (Testing the Framework)

This is the primary way to **validate the framework works end-to-end**. You create a fresh project, wire up the framework, and tell the orchestrator to build something.

### Step 1: Create a target project

```bash
mkdir my-test-app
cd my-test-app
git init
```

### Step 2: Install the framework into your project

```bash
# Copy the governance constitution
cp /path/to/agentic-workflow/AGENTS.md .

# Copy language and domain contexts
cp -r /path/to/agentic-workflow/contexts/ ./contexts/
```

For **Cursor**, also ensure the agentic-sdlc plugin agents and skills are accessible (either installed via the plugin system or symlinked).

### Step 3: Open the project in your IDE

Open `my-test-app/` in Cursor (or Claude Code / Copilot).

### Step 4: Invoke the orchestrator with a requirement

In Cursor agent mode, use the **OrchestrateSDLC** agent:

```text
@OrchestrateSDLC "Build a task management REST API with user authentication,
JWT tokens, CRUD operations for tasks, and PostgreSQL persistence"
```

Or try simpler prompts to start:

```text
@OrchestrateSDLC "Build a hello-world REST API with health check endpoint using Python FastAPI"
```

### What happens next

The orchestrator will autonomously:

1. **Decompose** the requirement into stories (`stories.json`)
2. **Plan** each story with file paths, risks, and acceptance criteria
3. **Design** architecture (boundaries, patterns, technology choices)
4. **Implement** code following the detected language context and project structure standards
5. **Review** code, architecture, and security in parallel
6. **Generate and run tests** with coverage validation
7. **Generate** E2E tests, update documentation, create deployment artifacts
8. **Run quality gate** checks against all criteria
9. **Complete** the story with a PR-ready branch

### Example prompts for different stacks

**Java Spring Boot:**
```text
@OrchestrateSDLC "Build an inventory management microservice with Spring Boot,
JPA/PostgreSQL, REST API with pagination, and JWT authentication"
```

**Python FastAPI:**
```text
@OrchestrateSDLC "Build a URL shortener service with FastAPI, SQLAlchemy,
Redis caching, and rate limiting"
```

**.NET Clean Architecture:**
```text
@OrchestrateSDLC "Build a customer management API with ASP.NET Core,
Entity Framework Core, and Azure AD authentication"
```

**React Frontend:**
```text
@OrchestrateSDLC "Build a project dashboard SPA with React, TypeScript,
TanStack Query for data fetching, and a component library"
```

**Go Backend:**
```text
@OrchestrateSDLC "Build a notification service in Go with Gin,
WebSocket support, and message queue integration"
```

### Verifying the output

After the orchestrator completes, check these artifacts:

| Artifact | Location | What to verify |
|----------|----------|----------------|
| Stories | `./context/stories.json` | Decomposition is reasonable |
| Plans | `./memory/stories/*/plan.md` | Scope and file paths make sense |
| Code | `src/` or language-specific dirs | Compiles, follows standards |
| Tests | Test directories | Run `npm test` / `pytest` / `mvn test` etc. |
| Test results | `./context/test-results.json` | All green, coverage >= threshold |
| Quality gate | `./memory/stories/*/quality-gate-report.md` | PASS verdict |
| Deployment | `Dockerfile`, `k8s/`, `helm/` | Valid Docker build |
| Documentation | `README.md`, OpenAPI specs | Accurate and complete |

### Manual verification commands

```bash
# Check the generated project builds
# (Java)
mvn clean verify

# (Python)
pip install -r requirements.txt && pytest --cov

# (Node/React)
npm install && npm test

# (.NET)
dotnet build && dotnet test

# (Go)
go build ./... && go test ./...

# Check Docker builds
docker build -t my-test-app .
```

---

## Plugins

| Plugin | Description | Cursor | Claude Code | Copilot |
|--------|-------------|:------:|:-----------:|:-------:|
| **agentic-sdlc** | Full autonomous SDLC pipeline with 16 agents | Yes | Yes | Yes |
| **adm** | Base agentic development management | Yes | -- | -- |
| **security-governance** | Security governance rules and agents | Yes | -- | -- |
| **test-generation** | Test planning and generation | Yes | -- | -- |

See [`plugins/README.md`](plugins/README.md) for detailed installation instructions per IDE.

---

## Contexts

Contexts are short, checklist-style guidance files that agents load based on project signals.

### Language Contexts (exactly one loaded, by priority)

| Context | Trigger | Key guidance |
|---------|---------|-------------|
| `java.md` | `pom.xml`, `build.gradle`, `*.java` | JUnit 5, Mockito, thin controllers, Maven/Gradle conventions |
| `python.md` | `pyproject.toml`, `requirements*.txt`, `*.py` | pytest, boundary validation, typed domain errors |
| `dotnet.md` | `*.csproj`, `global.json`, `*.cs` | xUnit/NUnit/MSTest, Moq, solution structure |

### Domain Contexts (multiple may be loaded)

| Context | Trigger | Key guidance |
|---------|---------|-------------|
| `api-design.md` | OpenAPI/Swagger/GraphQL files | Validation, error envelopes, correlation IDs, pagination |
| `database.md` | `*.sql`, `migrations/`, Prisma | Parameterized queries, migration discipline, no destructive DDL |
| `security.md` | `**/security/**`, `**/auth/**`, jwt/oauth | Authz, untrusted input handling, secrets management |

---

## Skills

### Framework-level skills (`.cursor/skills/` and `.claude/skills/`)

| Skill | Purpose |
|-------|---------|
| **load-contexts** | Detect project signals and emit a ContextManifest |
| **draft-plan** | Create an enterprise implementation plan with acceptance criteria |
| **security-audit** | OWASP-style review with structured findings |
| **generate-tests** | Deterministic test plan and generation |

### Agentic-SDLC plugin skills (13 total)

| Skill | Purpose |
|-------|---------|
| manage-context | Read/write/update session JSON state |
| git-checkpoint | Create tagged commits at phase boundaries |
| decompose-requirements | Break features into stories with dependencies |
| detect-language | Identify project language and load context |
| run-tests | Execute test suites and capture results |
| validate-coverage | Check coverage against threshold |
| generate-e2e | Create end-to-end API/UI journey tests |
| quality-gate | Evaluate G1-G8 criteria with evidence |
| detect-deployment | Identify deployment target and generate artifacts |
| compact-context | Summarize context to manage token budget |
| trace-collector | Emit structured trace records |
| handover | Package session state for orchestrator continuity |
| ad-hoc-delegate | Dynamic delegation to specialist agents |

---

## Multi-IDE Support

| Feature | Cursor | Claude Code | GitHub Copilot |
|---------|--------|-------------|----------------|
| Native agents | Yes (`.agent.md`) | Yes (`.agent.md`) | Prompt packages (`.agent.md`) |
| Skills | Yes | Yes | Manual workflow |
| Hooks (guardrails) | Yes (PowerShell/bash) | Yes (bash) | N/A |
| MCP integration | Yes | Yes | N/A |
| Full orchestration | Automated | Automated | Human-guided |

---

## MCP Integrations

The **adm** and **agentic-sdlc** plugins configure two MCP servers:

| Server | Purpose | URL |
|--------|---------|-----|
| **GitHub** | PR creation, code search, issue management | `https://api.githubcopilot.com/mcp/x/all` |
| **Atlassian** | Jira ticket retrieval, status updates | `https://mcp.atlassian.com/v1/mcp` |

Configure these in your IDE's MCP settings or in the plugin's `mcp.json` file.

---

## Standards Library

The agentic-sdlc plugin ships an extensive standards library:

### Coding Standards (9)
Naming conventions, readability, exception handling, concurrency, performance, I/O management, cryptography, input validation, dependency management.

### Project Structure Templates (9)
Java Spring Boot, Java Quarkus, Python FastAPI, Python Django, Python Flask, Go, .NET, React, Angular.

### API Standards
REST conventions (versioning, pagination, error envelopes).

### Database Standards
Migration discipline, parameterized queries, transaction boundaries.

### Security Standards
OWASP checklist for agent-generated code.

### UI Standards (4)
UI generation guidelines, design tokens, component catalog, accessibility checklist.

### Deployment Standards (3)
Containerization, Kubernetes, Helm, CI/CD pipelines.

---

## Deployment Templates

Ready-to-use templates for multiple platforms:

| Category | Templates |
|----------|-----------|
| **Dockerfiles** | Java Spring, Python FastAPI, Go, .NET, React, Angular |
| **Kubernetes** | Deployment, Service, Ingress, HPA, ConfigMap |
| **Helm** | Chart + values for dev, staging, prod, on-prem, AWS EKS, Azure AKS, GCP GKE |
| **CI/CD** | GitHub Actions, Azure Pipelines, Google Cloud Build |

---

## Configuration

| Parameter | Location | Default |
|-----------|----------|---------|
| Coverage threshold | QualityGate agent / CI env | 80% |
| Max retries per story | `stories.json` / session | 3 |
| Human approval required | `sdlc-session.json` | false |
| E2E tests enabled | Session or story flags | true |
| Token budgets | `observability/token-budget.json` | Per-phase ceilings |

---

## How to Run and Test

### Running the framework itself

This repository is a **governance and tooling package**, not a standalone application. To use it:

1. Install it into a target project (see [Quick Start](#quick-start))
2. Open the target project in your IDE
3. Invoke agents to generate, review, or test code

### Testing the framework

See [Generating an Application](#generating-an-application-testing-the-framework) for a complete walkthrough of end-to-end validation.

### Framework development

```bash
# Clone the repo
git clone <repo-url> agentic-workflow
cd agentic-workflow

# Verify structure
ls contexts/       # Should show 6 .md files
ls plugins/        # Should show 4 plugin directories
ls .cursor/agents/ # Should show agent definitions

# Open in Cursor for plugin development
# Edit agents in plugins/agentic-sdlc/cursor/agents/
# Edit skills in plugins/agentic-sdlc/cursor/skills/
# Edit standards in plugins/agentic-sdlc/standards/
```

---

## Contributing

1. Follow `AGENTS.md` as the highest-priority instruction
2. Use the A2A envelope format for inter-agent communication
3. Add or update contexts in `./contexts/` for new language/domain support
4. Add standards to `plugins/agentic-sdlc/standards/` following existing conventions
5. Test changes by generating an application (see above) and verifying the output
6. Update this README and relevant plugin READMEs for meaningful changes
