# Contributing to Agentic Workflow Framework

## Getting Started

1. Fork and clone the repository
2. Read `AGENTS.md` — it is the single source of truth
3. Read `contexts/PROJECT_CONTEXT.md` for project orientation
4. Review the plugin you plan to modify under `plugins/`

## Repository Conventions

### File structure
- `AGENTS.md` at root governs all agent behavior
- `contexts/` holds language and domain context files loaded deterministically
- `plugins/agentic-sdlc/` is the core SDLC plugin with IDE-specific subfolders (`cursor/`, `claude/`, `copilot/`)
- Each IDE subfolder must contain the same 16 agents with equivalent depth

### Agent parity
When adding or modifying an agent, update all three IDE variants:
- `claude/agents/<name>.md` — Claude Code format (YAML: name, model, effort, maxTurns)
- `cursor/agents/<Name>.agent.md` — Cursor format (YAML: name, model, tools, user-invocable)
- `copilot/agents/<name>.agent.md` — Copilot format (YAML: description, tools, engine: copilot)

### Content depth
Every agent must include: stopping rules, numbered workflow steps, output contract, and a full A2A envelope block. Target 80-150 lines per agent.

### Naming
- Cursor agents: PascalCase (`ImplementCode.agent.md`)
- Claude agents: kebab-case (`implementer.md`)
- Copilot agents: kebab-case with `.agent.md` suffix (`implementer.agent.md`)

## How to Test

Use the sample applications under `test-apps/` to verify framework changes:
```bash
cd test-apps/stock-ai-app
# Invoke OrchestrateSDLC with a test requirement
```

## Pull Requests

- Keep changes focused and minimal (per `AGENTS.md` section 14: surgical diffs)
- Verify agent parity across all three IDEs
- Update `README.md` if you add new capabilities
- Do not commit secrets, `.env` files, or credentials
