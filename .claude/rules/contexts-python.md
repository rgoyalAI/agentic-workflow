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
- When declaring dependencies, **always include required extras** (e.g., `pydantic[email]`, `uvicorn[standard]`, `sqlalchemy[asyncio]`). Verify that optional features used in code (like `EmailStr`, async drivers, etc.) have their corresponding extras declared in the manifest. A bare package name is insufficient if the code uses an optional sub-feature.
- Prefer `pytest` for unit/integration tests unless the repo already uses something else.
- Use deterministic tests: avoid time-dependent assertions without controlled clocks/fakes.
- **Test database isolation**: for async SQLAlchemy tests, use **in-memory SQLite with `StaticPool`** (`create_async_engine("sqlite+aiosqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)`). This ensures all connections share one in-memory database — no stale files, no WAL locking, no cross-connection isolation bugs. File-based SQLite (`test.db`) with async drivers causes subtle failures where `drop_all`/`create_all` on one connection is invisible to sessions on another. Always `drop_all` then `create_all` in the autouse setup fixture regardless.
- **Fixture resilience**: fixtures that create entities via API and extract response fields (e.g., `resp.json()["access_token"]`) MUST assert the response succeeded first (`assert resp.status_code == 201`). Without this, an upstream failure cascades as an opaque `KeyError` across every dependent test.
- Keep controllers/entrypoints thin; put business logic in well-named modules.
- Validate inputs at the boundary and raise/return typed domain errors that map to consistent API responses.
- **Use domain-specific exceptions** at service boundaries (e.g., `DuplicateEmailError`, `InvalidCredentialsError`), never catch broad `ValueError`/`Exception` at API route handlers — library code (bcrypt, ORM, serializers) also raises `ValueError`, so a broad catch silently converts unrelated internal errors into wrong HTTP status codes.
- **Password hashing**: use `bcrypt` package directly (`bcrypt.hashpw`/`bcrypt.checkpw`), NOT `passlib[bcrypt]`. The `passlib` library is incompatible with `bcrypt >= 4.1` and produces misleading errors.

## What not to do
- Do not add new production dependencies without explicit approval.
- Do not modify production code unless the task explicitly requires it.
- Do not write tests that mirror implementation details; assert observable behavior.
- Do not assume framework-specific HTTP status codes are stable across versions (e.g., FastAPI security dependencies may return 401 or 403 depending on version). Use range checks or `in` assertions for framework-controlled responses, and exact assertions only for your own application logic.

