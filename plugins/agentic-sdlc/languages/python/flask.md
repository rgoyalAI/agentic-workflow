# Flask Patterns for Agentic SDLC

Flask is a lightweight WSGI framework. Scale it with **application factories**, **blueprints**, and **extensions** so automated pipelines get repeatable builds and testable modules.

## Application Factory (`create_app`)

Avoid a global `app` for imports at module level in tests. Use **`create_app(config_name)`** to bind configuration and register extensions.

```python
from flask import Flask

def create_app(config_object=None):
    app = Flask(__name__)
    app.config.from_object(config_object or "config.DevelopmentConfig")

    from .extensions import db, migrate, cors
    db.init_app(app)
    migrate.init_app(app, db)
    cors.init_app(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})

    from .api import bp as api_bp
    app.register_blueprint(api_bp, url_prefix="/api/v1")

    from .errors import register_error_handlers
    register_error_handlers(app)

    return app
```

Entry point (`wsgi.py`): `app = create_app()` for production servers (gunicorn, uwsgi).

## Blueprints

Group routes by feature under **`blueprints`**. Each blueprint owns its URL prefix and templates subfolder if needed.

```python
# api/items.py
from flask import Blueprint, jsonify

bp = Blueprint("items", __name__)

@bp.get("/items/<item_id>")
def get_item(item_id: str):
    return jsonify({"id": item_id})
```

```python
# api/__init__.py
from flask import Blueprint
from . import items

bp = Blueprint("api", __name__)
bp.register_blueprint(items.bp)
```

This keeps circular imports manageable and mirrors feature ownership for code review.

## Extensions

Common extensions:

| Extension        | Role |
|-----------------|------|
| **Flask-SQLAlchemy** | ORM session bound to app context |
| **Flask-Migrate**    | Alembic migrations via CLI |
| **Flask-CORS**       | Controlled cross-origin access |
| **Flask-Login**      | Session-based auth |

Initialize extensions in **`extensions.py`** without `app` at import time; call `init_app` in the factory.

```python
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate

db = SQLAlchemy()
migrate = Migrate()
```

## Configuration Classes

Use classes inheriting from a base; select via env var in `create_app`.

```python
import os

class BaseConfig:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only")
    SQLALCHEMY_TRACK_MODIFICATIONS = False

class DevelopmentConfig(BaseConfig):
    DEBUG = True
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL", "sqlite:///dev.db")

class ProductionConfig(BaseConfig):
    DEBUG = False
    SQLALCHEMY_DATABASE_URI = os.environ["DATABASE_URL"]

class TestConfig(BaseConfig):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"

config_by_name = {
    "development": DevelopmentConfig,
    "production": ProductionConfig,
    "test": TestConfig,
}
```

## Testing

Use **pytest** with **pytest-flask** for a configured app fixture.

```python
import pytest
from myapp import create_app
from myapp.extensions import db

@pytest.fixture
def app():
    app = create_app("config.TestConfig")
    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()

def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
```

`client` fixture issues HTTP requests without running a real server. For integration tests against Postgres, use Docker Compose or Testcontainers in CI.

## CLI and tasks

Use **Flask CLI** (`flask --app wsgi:app`) for custom commands (`@app.cli.command()`) such as data backfills or cache warms. Keep destructive commands behind environment checks and explicit confirmation flags in production automation.

## Security defaults

- Set **`SESSION_COOKIE_SECURE=True`**, **`SESSION_COOKIE_HTTPONLY=True`**, and **`SESSION_COOKIE_SAMESITE='Lax'`** (or `Strict`) for cookie sessions.
- Enable **CSRF** for form posts; for APIs use token-based auth with short-lived credentials.
- Use **`werkzeug.middleware.proxy_fix.ProxyFix`** when behind load balancers so `request.remote_addr` and scheme are correct for logs and redirects.

## Logging and errors

Configure **`logging.dictConfig`** from JSON/YAML in `create_app`; log request ID from `g` or Werkzeug’s stream. Map unhandled exceptions to JSON error bodies in `register_error_handlers`—never return Python tracebacks to external callers.

## API conventions

Return **JSON** with consistent keys (`error`, `code`, `details`) and appropriate HTTP status codes. Validate request bodies with **Marshmallow** or **Pydantic** (as a separate layer) when Flask’s built-in parsing is insufficient—keep validation out of route functions as projects grow.

## Database sessions

With SQLAlchemy, scope session teardown with **`@app.teardown_appcontext`** or use **`scoped_session`** patterns carefully under concurrency. In tests, always run within **`app.app_context()`** when touching the database.

## Deployment

Run production WSGI with **gunicorn** + **gevent** or **uwsgi** workers behind nginx/Envoy. Set **`MAX_CONTENT_LENGTH`** to bound request sizes. Health checks should hit a lightweight **`/health`** route that verifies DB connectivity when the app depends on it.

## Typing and quality gates

Adopt **mypy** with **`--strict`** for services above a certain size; type hint route functions and service layers so Agentic SDLC reviews catch `None` handling early. Run **ruff** or **flake8** plus **black** in CI for consistent formatting.

## Agentic SDLC Checklist

- Single `create_app` path used by WSGI, CLI, and tests.
- Blueprints align with team boundaries; no monolithic `views.py`.
- Migrations committed alongside model changes (`flask db migrate` / `upgrade` in deploy).
- `TestConfig` isolates tests; no accidental prod DB URLs in CI logs.
- CORS and `SECRET_KEY` set from environment in staging/production.
