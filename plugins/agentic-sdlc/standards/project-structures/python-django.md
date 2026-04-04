# Python — Django (Settings Package + Apps per Bounded Context)

Django projects should use a **settings package** for environment splits and **one Django app per bounded context** (not one monolithic `app` for everything).

## Top-level layout

```
manage.py
config/                              # Project configuration package (rename from single settings.py if preferred)
├── __init__.py
├── settings/
│   ├── __init__.py                  # Imports base + env-specific
│   ├── base.py                      # INSTALLED_APPS, MIDDLEWARE, shared
│   ├── dev.py
│   └── prod.py
├── urls.py                          # Root URLConf — includes per-app urls
├── wsgi.py
└── asgi.py
apps/
├── accounts/                        # Bounded context: identity
│   ├── models.py
│   ├── views.py
│   ├── serializers.py             # DRF if used
│   ├── urls.py
│   ├── admin.py
│   ├── tests/
│   └── factories.py                 # factory_boy for tests
├── catalog/
└── orders/
templates/                           # Project-wide templates if needed
static/
requirements/
├── base.txt
├── dev.txt
└── prod.txt
```

## Apps as bounded contexts

- Each app under **`apps/<name>/`** owns its **models**, **views/viewsets**, **serializers**, **urls**, **admin**, and **tests/**.
- Cross-app imports: prefer **events** or **service layer** over circular model imports; use `apps` label in `INSTALLED_APPS` as `apps.accounts`.
- **`factories.py`** (or `factories/`) colocated for test data builders.

## Settings

- **`base.py`**: `INSTALLED_APPS`, database defaults, `AUTH_USER_MODEL` if custom, middleware, templates, static finders.
- **`dev.py`**: `DEBUG=True`, console email, local DB.
- **`prod.py`**: `DEBUG=False`, secure cookies, static/media from object storage, logging to stdout JSON.

Select via `DJANGO_SETTINGS_MODULE=config.settings.dev` or equivalent.

## Requirements

- **`requirements/base.txt`**: pinned runtime deps.
- **`requirements/dev.txt`**: `-r base.txt` + dev tools (pytest, ipdb, django-debug-toolbar).
- **`requirements/prod.txt`**: `-r base.txt` + gunicorn, observability libs.

## Tests

- **`apps/<app>/tests/`**: `test_models.py`, `test_views.py`, `test_api.py`; use **`pytest-django`** or Django test runner consistently.
- Keep **factories** next to apps for discoverability.

## Key rules

1. **Settings package** — no secrets in repo; use env vars and `django-environ` or similar.
2. **One app per bounded context** — resist dumping unrelated models into `core`.
3. **DRF serializers** live in the app that owns the resource.
4. **Migrations** per app: `python manage.py makemigrations` — review and commit.

## Anti-patterns

- `from apps.orders.models import Order` inside unrelated apps' models without a documented integration pattern — leads to tight coupling.
- Putting all URLs in a single `urls.py` without `include()` per app — hard to navigate at scale.
