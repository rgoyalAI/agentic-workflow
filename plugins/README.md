# Multi-IDE Plugin Structure

This directory contains multiple "agentic" plugins packaged for:
- Cursor (Cursor plugin format)
- Claude Code (Claude Code plugin format)
- GitHub Copilot (Copilot adapter files; typically copied into repo-level `.github/`)

## Available Plugins

| Plugin | Description | Cursor | Claude | Copilot |
|--------|-------------|--------|--------|---------|
| **adm** | Base agentic development management: planning, implementation, and verification | Yes | -- | -- |
| **security-governance** | Security governance rules, skills, and agents for agentic coding workflows | Yes | -- | -- |
| **test-generation** | Test planning and generation support for agentic coding workflows | Yes | -- | -- |
| **agentic-sdlc** | Autonomous SDLC pipeline with 16 specialized AI agents: decomposes requirements into stories, executes plan-design-implement-review-test-deploy-gate workflow | Yes | Yes | Yes |

## Conventions
- Plugin root: `plugins/<plugin-name>/`
- Cursor plugin package root: `plugins/<plugin-name>/cursor/` (contains `.cursor-plugin/plugin.json`)
- Claude plugin package root: `plugins/<plugin-name>/claude/` (contains `.claude-plugin/plugin.json`)
- Copilot adapter: `plugins/<plugin-name>/copilot/` (includes `.agent.md` + workflow markdown)

## Install/Use (high level)
- **Cursor**: Install/load the plugin from the `cursor/` subfolder.
- **Claude Code**: Load/install the plugin from the `claude/` subfolder.
- **Copilot**: Copy the `copilot/` adapter files into the repository's `.github/` as needed.

## Agentic SDLC Plugin (Detailed)

The `agentic-sdlc` plugin is the most comprehensive plugin in this collection. It provides:

- **16 specialized agents**: OrchestrateSDLC, DecomposeRequirements, PlanStory, DesignArchitecture, ImplementCode, ReviewCode, ReviewArchitecture, ReviewSecurity, GenerateTests, RunTests, ValidateCoverage, GenerateE2E, GenerateDeployment, UpdateDocumentation, QualityGate, CompleteStory
- **13 skills**: manage-context, git-checkpoint, decompose-requirements, detect-language, run-tests, validate-coverage, generate-e2e, quality-gate, detect-deployment, compact-context, trace-collector, handover, ad-hoc-delegate
- **Multi-language support**: Java (Spring Boot, Quarkus), Python (FastAPI, Django, Flask), Go (Gin, Echo, stdlib), .NET (Clean Architecture), React, Angular
- **Multi-cloud deployment**: On-prem, Azure AKS, AWS EKS, GCP GKE with Dockerfiles, K8s manifests, Helm charts, CI/CD pipelines
- **Enterprise standards**: 9 coding standards, 9 project structure templates, 4 UI generation standards, OWASP security checklist, REST API standards, database migration standards
- **Guardrails**: Calibrated autonomy model, hook-based enforcement, token budget controls
- **Observability**: Agent trace schema, correlation IDs, token budgets, spending caps

See [`plugins/agentic-sdlc/README.md`](agentic-sdlc/README.md) for full documentation.

