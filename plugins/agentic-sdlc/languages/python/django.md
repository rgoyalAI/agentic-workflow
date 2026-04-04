# Django Patterns for Agentic SDLC

Django provides batteries-included web stack with ORM, auth, and admin. Pair with **Django REST Framework (DRF)** for APIs. Structure projects for testability, environment-specific settings, and clear data boundaries.

## Django ORM

Define models in `models.py` (or split per module). Use **custom managers** for common filters and **querysets** for chainable logic.

```python
from django.db import models

class ActiveQuerySet(models.QuerySet):
    def active(self):
        return self.filter(is_active=True)

class ProductManager(models.Manager):
    def get_queryset(self):
        return ActiveQuerySet(self.model, using=self._db)

    def active(self):
        return self.get_queryset().active()

class Product(models.Model):
    sku = models.CharField(max_length=64, unique=True)
    is_active = models.BooleanField(default=True)

    objects = ProductManager()
```

- Prefer **`select_related`** / **`prefetch_related`** to avoid N+1 queries in serializers and views.
- Use **`F()` / `Q()`** for database-side expressions; avoid Python-side aggregation when SQL can do it.

### Migrations and constraints

Prefer **database-level uniqueness and checks** where appropriate (`UniqueConstraint`, `CheckConstraint` in `Meta.constraints`) so integrity holds even if application code paths diverge. Squash migrations periodically on long-lived projects to keep startup time predictable—plan squashes in maintenance windows.

### Performance

Add **`db_index=True`** on filtered foreign keys and high-cardinality lookup fields when profiling shows sequential scans. Use **`only()` / `defer()`** sparingly to trim columns; mispredicted deferred fields cause extra queries.

## Django REST Framework

**Serializers** define input validation and output shape; **viewsets** + **routers** reduce boilerplate for CRUD APIs.

```python
from rest_framework import serializers, viewsets
from rest_framework.permissions import IsAuthenticated

class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = ["id", "sku", "is_active"]

class ProductViewSet(viewsets.ModelViewSet):
    queryset = Product.objects.active()
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticated]
```

Use **`get_queryset()`** for row-level scoping (e.g., tenant). Prefer **explicit actions** (`@action`) over fat views.

### Pagination and filtering

Enable **`PageNumberPagination`** or **cursor pagination** for list endpoints; cap `page_size` to protect the database. Use **`django-filter`** or DRF **`filter_backends`** for query params—whitelist fields to avoid arbitrary column filters.

### Versioning

Version APIs via URL (`/api/v1/`) or **`Accept` header** negotiation; document breaking changes in release notes. Deprecate fields using serializer **`SerializerMethodField`** or extra metadata before removal.

## App-Based Structure

Use **one Django app per bounded context** when the project grows:

```
project/
  settings/
    __init__.py
    base.py
    development.py
    production.py
  catalog/
    models.py
    serializers.py
    views.py
    urls.py
  orders/
    ...
```

Register apps in `INSTALLED_APPS`. Cross-app imports should go through stable interfaces (services layer), not circular model imports.

## Testing

**`django.test.TestCase`** wraps tests in transactions and provides client:

```python
from django.test import TestCase
from django.urls import reverse

class ProductApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("u", password="x")
        self.client.login(username="u", password="x")

    def test_list_products(self):
        url = reverse("product-list")
        r = self.client.get(url)
        self.assertEqual(r.status_code, 200)
```

Use **factory_boy** for concise fixtures:

```python
import factory
from catalog.models import Product

class ProductFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Product
    sku = factory.Sequence(lambda n: f"SKU-{n}")
```

**pytest-django** integrates pytest with Django DB fixtures (`@pytest.mark.django_db`). Pick one primary style per repo for CI consistency.

## Settings Split

**`base.py`**: installed apps, middleware, templates, shared config. **`development.py`**: `DEBUG=True`, local DB, verbose logging. **`production.py`**: `DEBUG=False`, security headers, `ALLOWED_HOSTS`, Sentry, static files behind CDN.

```python
# settings/production.py
from .base import *

DEBUG = False
ALLOWED_HOSTS = os.environ["ALLOWED_HOSTS"].split(",")
SECRET_KEY = os.environ["SECRET_KEY"]
```

Never commit secrets; use environment variables or secret managers in Agentic SDLC deploy steps.

## Admin Customization

Register models with **`ModelAdmin`** for operational visibility: `list_display`, `search_fields`, `readonly_fields`, and **`inlines`** for related editing.

```python
from django.contrib import admin
from .models import Product

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("sku", "is_active")
    search_fields = ("sku",)
```

Restrict admin URL exposure in production (VPN, IP allowlist, or separate deployment).

## Signals

Use **signals** sparingly for side effects (cache invalidation, audit hooks). Prefer explicit service functions for core workflows to keep control flow visible.

```python
from django.db.models.signals import post_save
from django.dispatch import receiver

@receiver(post_save, sender=Product)
def product_saved(sender, instance, **kwargs):
    invalidate_product_cache(instance.sku)
```

Document signal handlers; overuse creates implicit coupling that harms testing.

## Background tasks

For Agentic SDLC workflows that enqueue work (reports, notifications), prefer **Celery** or **Django Q** with explicit retries and idempotency keys. Avoid long-running work in request threads; pass primary keys, not ORM instances, across process boundaries.

## Static files and ASGI

Serve static/media via **WhiteNoise** or reverse proxy (nginx/CDN) in production. For WebSockets or async views, run **Django ASGI** (uvicorn/daphne) with a clear split between sync ORM views and async consumers.

## Caching

Use **`django.core.cache`** (Redis/Memcached) for idempotent reads; key namespaced by tenant/version. Invalidate caches in **`post_save`** / **`post_delete`** signals or explicit service methods—document TTLs for Agentic SDLC observability dashboards.

## Security headers

Enable **`SecurityMiddleware`**, **`SECURE_SSL_REDIRECT`**, **`SESSION_COOKIE_SECURE`**, and **`CSRF_COOKIE_SECURE`** in production settings. Use **`django-cors-headers`** with explicit origins for SPA APIs.

## Management commands

Encapsulate recurring operational tasks (**`manage.py`** commands) for data fixes and backfills. Accept **`--dry-run`** flags and log counts before writes so Agentic SDLC automation can preview impact in staging.

## File uploads and async

For large uploads, stream to object storage (S3-compatible) rather than buffering entire files in memory. When using **async views**, remember ORM calls may still block unless you adopt async-capable database layers—document threading model per deployment.

## Agentic SDLC Checklist

- Migrations generated and reviewed for every model change (`makemigrations` / `migrate` in CI).
- DRF permissions and queryset scoping audited for new endpoints.
- Settings modules never contain production secrets in VCS.
- Tests cover serializers (invalid input) and critical views.
- Admin and signals documented when they affect compliance or billing.
