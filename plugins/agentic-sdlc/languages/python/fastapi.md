# FastAPI Patterns for Agentic SDLC

FastAPI combines async-first design, Pydantic validation, and OpenAPI generation. Use these patterns for maintainable APIs, testable layers, and clear error semantics in automated SDLC workflows.

## Async Patterns

Prefer **`async def`** for endpoints that await I/O (HTTP clients, DB drivers that support async, Redis). Use **`asyncio`** for coordinating concurrent work; avoid blocking calls inside async routes—offload CPU work with `run_in_executor` or use sync endpoints with a threadpool strategy.

```python
import httpx
from fastapi import APIRouter

router = APIRouter()

@router.get("/users/{user_id}/profile")
async def get_profile(user_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        r = await client.get(f"https://upstream.example/users/{user_id}")
        r.raise_for_status()
        return r.json()
```

**httpx** supports both sync and async clients; standardize on `AsyncClient` in async apps. Share a client via lifespan events rather than per-request instantiation when appropriate.

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.http = httpx.AsyncClient(base_url=settings.UPSTREAM_URL, timeout=10.0)
    yield
    await app.state.http.aclose()

app = FastAPI(lifespan=lifespan)
```

### CPU-bound and sync endpoints

If you must call blocking libraries (some SDKs, legacy ORMs), either:

- Expose a **sync** `def` route so FastAPI runs it in a threadpool, or
- Use **`asyncio.to_thread`** / **`run_in_executor`** explicitly for isolated blocking sections.

Do not mix uncontrolled blocking calls inside `async def` handlers—this stalls the event loop and harms latency under concurrency.

### Structured concurrency

For fan-out HTTP or DB calls, prefer **`asyncio.TaskGroup`** (Python 3.11+) or **`asyncio.gather`** with explicit exception handling so one failure does not leave sibling tasks orphaned.

```python
async def aggregate(user_id: str) -> dict:
    async with asyncio.TaskGroup() as tg:
        t1 = tg.create_task(profile_svc.get(user_id))
        t2 = tg.create_task(prefs_svc.get(user_id))
    return {"profile": t1.result(), "prefs": t2.result()}
```

## Pydantic v2 Models

Use **`BaseModel`** for request/response schemas. Leverage **`Field`** for defaults, constraints, and documentation.

```python
from pydantic import BaseModel, Field, field_validator

class CreateItem(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    quantity: int = Field(gt=0)

    @field_validator("name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        return v.strip()
```

Use **model_config** for ORM integration (`from_attributes=True`) when mapping SQLAlchemy rows to response models.

### Config and secrets

Load settings with **Pydantic Settings** (`BaseSettings`) from environment variables; never hardcode API keys. Use **field aliases** for env names (`database_url: str = Field(alias="DATABASE_URL")`).

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    database_url: str
    log_level: str = "INFO"

settings = Settings()
```

## Dependency Injection (`Depends`)

Encapsulate auth, DB sessions, and feature flags in **`Depends()`** callables for testability and reuse.

```python
from typing import Annotated
from fastapi import Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db() -> AsyncSession:
    async with session_factory() as session:
        yield session

async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    user = await users.get_by_token(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    return user

CurrentUser = Annotated[User, Depends(get_current_user)]
```

Keep dependency functions **pure aside from I/O**; business logic belongs in services.

## Project Structure

```
app/
  main.py                 # FastAPI app, lifespan, middleware
  api/
    deps.py               # shared dependencies
    v1/
      __init__.py
      router.py           # include_router aggregation
      items.py            # routes
  models/                 # SQLAlchemy ORM models (if using SQLAlchemy)
  schemas/                # Pydantic models (API contracts)
  services/               # domain / application logic
  repositories/         # data access
  core/
    config.py
    exceptions.py
```

Version routes under **`/api/v1`**; mount routers in `router.py` for a single import in `main.py`.

### Middleware and CORS

Add **`CORSMiddleware`** with explicit origins for browser clients. Use **`GZipMiddleware`** for large JSON when appropriate. Implement a small ASGI middleware to inject **`X-Request-ID`** from headers or generate a UUID for correlation across logs.

```python
from starlette.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["*"],
)
```

## Testing

Install **pytest-asyncio** and mark async tests with `@pytest.mark.asyncio`. Use **`httpx.AsyncClient`** with FastAPI’s **`ASGITransport`** for async integration tests, or **`TestClient`** for synchronous style.

```python
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_health():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        r = await ac.get("/health")
    assert r.status_code == 200
```

Override dependencies in tests with `app.dependency_overrides[get_db] = fake_db`.

### Contract and load testing

Generate OpenAPI from FastAPI (`app.openapi_url`) and optionally diff schemas in CI when APIs change. For performance gates, run **locust** or **k6** against staging with realistic payloads; store baseline latency for regressions.

## Alembic Migrations

Treat schema as code: **Alembic** revisions live in `alembic/versions/`. Run `alembic upgrade head` in deploy pipelines; generate migrations with `alembic revision --autogenerate` after model changes, then review autogenerated ops.

```ini
# alembic.ini — sqlalchemy.url from env in env.py
```

Never apply destructive migrations without a backup and approval gate in production.

## Error Handling

Define **domain exceptions** in `core/exceptions.py` and register **handlers** on the app.

```python
from fastapi import Request
from fastapi.responses import JSONResponse

class NotFoundError(Exception):
    def __init__(self, resource: str, id: str):
        self.resource = resource
        self.id = id

async def not_found_handler(request: Request, exc: NotFoundError):
    return JSONResponse(
        status_code=404,
        content={"detail": f"{exc.resource} {exc.id} not found", "code": "NOT_FOUND"},
    )

app.add_exception_handler(NotFoundError, not_found_handler)
```

For validation errors, customize `RequestValidationError` handler to return a stable JSON shape with `request_id` if you propagate correlation IDs.

### Logging

Use **structlog** or **`logging` with JSON formatter** in production; include `request_id`, `path`, and `status_code` on access logs. Redact `Authorization` headers at the logging boundary.

## OpenAPI and documentation

FastAPI auto-generates **`/openapi.json`**. For public APIs, add **`description`**, **`summary`**, and **response models** to every route so generated docs stay trustworthy—Agentic SDLC review agents can diff OpenAPI between commits.

```python
@router.post("/items", response_model=ItemOut, status_code=201)
async def create_item(body: ItemIn) -> ItemOut:
    ...
```

## Rate limiting and size limits

Put **reverse-proxy rate limits** (nginx, Envoy, API Gateway) as the first line of defense. In-app, reject oversized bodies via **`Request`** limits or middleware; validate **`Content-Length`** for upload endpoints.

## Background workers

For long tasks, publish messages to **Redis/RabbitMQ/SQS** and process in **Celery** or **ARQ** workers—keep HTTP handlers fast and idempotent. Share Pydantic models or JSON schemas between API and worker packages to avoid drift.

## Observability

Export **OpenTelemetry** traces from Starlette/FastAPI when using **`opentelemetry-instrumentation-fastapi`**. Attach **`trace_id`** to structured logs for cross-service correlation in Agentic SDLC incident workflows.

## WebSockets and SSE

For **WebSockets**, use Starlette’s **`WebSocket`** endpoints with explicit subprotocol auth. For **SSE**, stream with **`StreamingResponse`** and heartbeat comments to survive proxies—document reconnect backoff on the client.

## Agentic SDLC Checklist

- Async stack used consistently; no hidden blocking in async routes.
- Pydantic v2 models versioned with API (`v1` vs `v2` schemas if needed).
- Dependencies injectable and overridden in tests.
- Alembic migration per schema change; CI runs upgrade against ephemeral DB.
- Exception handlers return machine-readable codes; no raw stack traces to clients.
