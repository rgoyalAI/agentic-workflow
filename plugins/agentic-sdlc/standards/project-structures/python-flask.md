# Python — Flask (Application Factory + Blueprints)

Flask favors **application factories** and **blueprints** for modularity. Group code by feature blueprint, keep extensions centralized, and isolate configuration per environment.

## Layout

```
app/
├── __init__.py                      # create_app(config_name) — registers blueprints, extensions
├── extensions.py                    # db = SQLAlchemy(), migrate = Migrate(), csrf, etc.
├── config.py                        # Config, DevelopmentConfig, ProductionConfig
├── auth/                            # Blueprint: auth
│   ├── __init__.py
│   ├── routes.py
│   ├── forms.py
│   └── services.py
├── orders/
│   └── ...
├── api/                             # Optional JSON API blueprint
│   └── v1/
├── templates/                       # Jinja hierarchy (or per-blueprint subfolders)
├── static/
migrations/                          # Flask-Migrate / Alembic
tests/
├── conftest.py
├── test_auth.py
└── test_orders.py
wsgi.py                              # app = create_app('production')
```

## Application factory (`app/__init__.py`)

- **`create_app(config_name)`** instantiates Flask, loads `config.py` object, initializes **`extensions.py`** (bind `db` to app), registers **blueprints** with URL prefixes.
- No module-level `app = Flask(__name__)` for production code — factory enables testing and multiple configs.

## Blueprints

- One folder per **feature** (`auth/`, `orders/`): **`routes.py`** defines views; **`services.py`** holds logic; optional **`forms.py`** for WTForms.
- Register: `app.register_blueprint(auth_bp, url_prefix='/auth')`.

## Configuration

- **`config.py`**: class-per-environment; secrets from `os.environ`; `TESTING`, `SQLALCHEMY_DATABASE_URI`, session settings.
- **`.env`** for local only (gitignored); document variables in README.

## Extensions (`extensions.py`)

- Import **unbound** extension objects (`SQLAlchemy()`, `Migrate()`) and call `init_app(app)` in factory — avoids circular imports.

## Migrations

- **Flask-Migrate** on top of Alembic: `migrations/` at repo root; run `flask db migrate` / `flask db upgrade` in CI/CD.

## Testing

- **`conftest.py`**: `app` fixture with `create_app('testing')`, in-memory SQLite, `client` fixture.
- Test blueprints in isolation where possible; integration tests hit full app.

## Key rules

1. **Factory pattern** — mandatory for services larger than a script.
2. **Blueprints** — feature boundaries; shared UI in `templates/` with clear naming.
3. **Thin routes** — delegate to services; keep WTForms/validation at edge.
4. **Thread/process safety** — document deployment model (gunicorn workers) when using global state (avoid).

## Anti-patterns

- Single `views.py` with hundreds of routes — split by blueprint.
- Initializing extensions twice or importing `app` before factory runs — use lazy patterns consistent with Flask docs.
