# Python — FastAPI (Layered App Package)

FastAPI projects should separate **HTTP routing**, **domain/services**, **persistence**, and **schemas** cleanly. This layout scales to multiple API versions and shared core utilities.

## Directory layout

```
app/
├── main.py                          # FastAPI app factory, lifespan, router inclusion
├── config.py                        # Pydantic Settings, env-based config
├── database.py                      # Engine, session factory, Base for ORM
├── dependencies.py                  # FastAPI Depends() — auth, DB session, feature flags
├── exceptions.py                    # Custom exceptions + handlers registration
├── middleware.py                    # CORS, request ID, timing, security headers
├── api/
│   └── v1/
│       ├── __init__.py
│       ├── router.py                # Aggregates v1 endpoints
│       └── endpoints/             # users.py, orders.py — thin routers
├── models/                          # SQLAlchemy (or other) ORM models
├── schemas/                         # Pydantic request/response models (NOT ORM)
├── services/                        # Business logic, transactions, orchestration
├── repositories/                    # Data access per aggregate or table
└── core/                            # Security utils, constants, base types
migrations/                          # Alembic: versions/, env.py, script.py.mako
tests/
├── conftest.py                      # Fixtures: client, db, factories
├── api/v1/
└── services/
```

## Versioning

- Expose APIs under **`/api/v1/`**, **`/api/v2/`** as separate routers (`api/v1/`, `api/v2/`).
- **Never** break v1 contract in place; add v2 and deprecate with sunset headers/docs.

## Key rules

1. **Thin routers**: Endpoints parse/validate input (Pydantic), call a **service**, return `schemas`. No SQL in route handlers.
2. **Business logic in `services/`**: One module or class per bounded-context operation; repositories for DB I/O.
3. **Pydantic separate from ORM**: `schemas/` for API; `models/` for tables. Explicit mapping (manual or helper) — avoid returning ORM objects from routes.
4. **`dependencies.py`**: Centralize `get_db`, `get_current_user`, etc., for testability.
5. **Alembic** in `migrations/`: All DDL via revisions; align with `database.py` models.

## `main.py` responsibilities

- Create `FastAPI()` instance, attach middleware, include versioned routers.
- Register exception handlers from `exceptions.py`.
- Configure OpenAPI metadata (title, version, servers).

## Testing

- **`conftest.py`**: `TestClient` or async client fixture, transactional DB or SQLite in-memory, override `get_db`.
- Mirror **`tests/api/`** structure under `app/api/` for endpoint tests.
- Service tests mock repositories; integration tests hit real DB (e.g. Docker).

## Anti-patterns

- Giant `crud.py` files mixing all entities — split by feature or aggregate.
- Using the same Pydantic model for ORM and API without separation — causes leakage of internal fields and tight coupling.
