# Agentic SDLC — GitHub Copilot Chat packaging

This folder packages **prompting assets** and **workflow references** for teams using **GitHub Copilot** in VS Code or GitHub.com. It mirrors the Agentic SDLC pipeline concepts from the Cursor and Claude Code variants, with Copilot-specific constraints (single-turn context, no native multi-agent runtime).

## Installation

1. Copy the contents of **`copilot/`** into your target repository’s **`.github/`** directory (merge with existing files—do not delete unrelated workflows).
2. Rename or merge **`copilot-instructions.md`** to **`.github/copilot-instructions.md`** (or merge its rules into your existing Copilot instructions file).
3. Copy **`agents/*.agent.md`** to **`.github/agents/`** (create the folder if missing). Adjust paths in `copilot-instructions.md` if you prefer another location.

Repository root should still contain **`AGENTS.md`** as the single source of truth for humans and tools.

## Invoking “agents” in Copilot Chat

Copilot does not run separate agent processes. Use agent files as **structured system prompts**:

1. Open **Copilot Chat** in VS Code or on GitHub (where supported).
2. Use **@workspace** (or attach folders) so Copilot can read `AGENTS.md` and standards.
3. Paste or reference the desired **`.github/agents/<name>.agent.md`** file (e.g. “Follow the orchestrator agent definition in `.github/agents/orchestrator.agent.md`”) and state your task (e.g. “Orchestrate the next story using session state in `./context/`”).
4. For long pipelines, **split manually**: decomposition → planning → implementation → reviews → tests → gate—one phase per chat thread with explicit handoff summaries.

## GitHub Actions workflows

Example CI definitions live under **`workflows/`** in this package as **Markdown documents with embedded YAML** for copy-paste:

- **`workflows/agentic-sdlc.md`** — optional dispatch or scheduled job that documents how a full SDLC pipeline could be triggered from CI (human-in-the-loop recommended).
- **`workflows/ci-quality-gate.md`** — quality gate checks (build, test, coverage thresholds) suitable for PR validation.

Copy the YAML blocks from those files into **`.github/workflows/*.yml`** in your repo and customize branches, runners, and secrets.

## Limitations vs Cursor / Claude Code

| Aspect | Cursor / Claude plugin | Copilot Chat |
|--------|------------------------|--------------|
| Multi-agent runtime | Orchestrator + specialists | **Manual**; you play orchestrator |
| Session state | `./context/sdlc-session.json` | You must persist and paste summaries |
| Hooks / blocked commands | Claude hooks, IDE rules | **Not automatic**; rely on branch protection and CI |
| MCP (Jira/GitHub) | Configured in IDE | Use GitHub UI or Actions; Copilot may not have MCP |
| Long-running retries | Scripted loops | **Manual** or custom Actions |

Use this package for **consistent instructions and PR/CI gates**; use Cursor or Claude Code plugins for **fully automated** multi-agent runs when available.

## Related paths in this plugin

- **Standards:** `standards/coding/`, `standards/project-structures/`, `standards/deployment/`
- **Cursor agents:** `../cursor/agents/` (full 16-agent set)
- **Claude Code:** `../claude/` (plugin manifest, agents, skills, hooks)

## Security

Never commit secrets. Copilot instructions and workflows should reference **secret names** and **OIDC**—not long-lived tokens in YAML.
