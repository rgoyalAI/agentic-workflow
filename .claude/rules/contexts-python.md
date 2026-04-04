---
paths:
  - "pyproject.toml"
  - "requirements*.txt"
  - "**/*.py"
---

# Context: Python

## When to use
- `project.language == Python`

## How to apply
- Follow the repo's existing dependency management (e.g., `pyproject.toml`, `requirements*.txt`); do not invent tooling.
- Prefer `pytest` for unit/integration tests unless the repo already uses something else.
- Use deterministic tests: avoid time-dependent assertions without controlled clocks/fakes.
- Keep controllers/entrypoints thin; put business logic in well-named modules.
- Validate inputs at the boundary and raise/return typed domain errors that map to consistent API responses.

## What not to do
- Do not add new production dependencies without explicit approval.
- Do not modify production code unless the task explicitly requires it.
- Do not write tests that mirror implementation details; assert observable behavior.

