---
name: manage-context
description: Reads, writes, and manages structured context files in the ./context/ and ./memory/ directories. Use for reading stories.json, writing test-results.json, updating session state, or extracting specific fields from context files without loading entire contents.
---

# Manage Context

## Purpose

Standardized context file operations for the Agentic SDLC workflow. Keeps orchestrator and specialist agents aligned on **where state lives**, how to update it safely, and how to stay within token limits by reading only what is needed.

## Operations

### Read context file

- Open a file under `./context/` or `./memory/` by path.
- For large JSON, prefer parsing and retaining only the fields required for the current step.

### Write context file

- Serialize validated JSON (or approved text format) to the target path.
- Create parent directories if the workflow allows and the path is under `./context/` or `./memory/`.

### Update field

- Read the existing document, apply a minimal patch to the requested field (e.g., `currentStoryId`, `retryCount`, `gate.verdict`), write back.
- For JSON: validate after merge; reject partial writes that would corrupt structure.

### List context directory

- Enumerate files in `./context/` or `./memory/` to discover `stories.json`, `sdlc-session.json`, `test-results.json`, and other artifacts without guessing paths.

### Extract field from JSON

- Use JSON Pointer or explicit key paths to return a single value or subtree (e.g., `stories[2].id`, `coverage.lines`) without passing the full file to the orchestrator prompt.

## File locations

| Area | Path | Use |
|------|------|-----|
| Runtime session & artifacts | `./context/` | `sdlc-session.json`, `stories.json`, `test-results.json`, gate outputs |
| Persistent memory bank | `./memory/` | Longer-lived summaries, decision logs (project-specific) |

Paths are relative to the workspace root unless the orchestrator session explicitly sets a different root.

## Safety

- **Never overwrite without reading first** unless creating a brand-new file that must not exist yet; if the file exists, read, merge, then write.
- **Always validate JSON** before writing: reject trailing garbage, duplicate keys, or type mismatches.
- Do not store secrets in context files; use environment or secret managers per `AGENTS.md`.

## Token efficiency

- Prefer **selective field extraction** over dumping entire files into chat.
- When only counts or ids are needed, return those fields and the file path for specialists to open locally.
