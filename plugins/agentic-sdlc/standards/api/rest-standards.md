# REST API Standards

Enterprise REST APIs follow **consistent versioning**, **predictable pagination**, **standardized errors**, and **contract-first** development.

## Versioning

- **Path versioning** (preferred for public APIs): `/api/v1/resources`, `/api/v2/resources`.
- **Header versioning** (alternative): `Accept: application/vnd.company.v1+json` — document in OpenAPI; use only if gateway standard mandates.
- **Rules**: Never ship breaking changes under the same major version; deprecate with `Deprecation` / `Sunset` headers and changelog.

## Pagination

Support **cursor-based** pagination for large, frequently changing collections:

```json
{
  "data": [ ... ],
  "page": {
    "next_cursor": "opaque-token",
    "has_more": true,
    "limit": 50
  }
}
```

- **`limit`**: Max cap (e.g. 100); reject or clamp oversized requests with **400**.
- **Offset pagination** (`page`, `page_size`) allowed for admin or small datasets — document consistency caveats.

## Error envelope

All error responses use a **single JSON shape**:

```json
{
  "status": 422,
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Human-readable summary",
    "correlation_id": "uuid-or-trace",
    "details": [
      { "field": "email", "issue": "invalid_format" }
    ]
  }
}
```

- **`correlation_id`**: Echo from `X-Correlation-ID` or generate; **never** omit on 5xx.
- **Do not** leak stack traces or internal hostnames in production.

## HATEOAS (optional but recommended)

- Include **`_links`** or `links` for discoverability where it reduces client coupling:

```json
{
  "data": { "id": "ord_1", "status": "open" },
  "links": {
    "self": { "href": "/api/v1/orders/ord_1" },
    "cancel": { "href": "/api/v1/orders/ord_1/cancel", "method": "POST" }
  }
}
```

- Use **templated** links sparingly; document relation names in OpenAPI.

## OpenAPI first

- **Authoritative** OpenAPI 3.x in repo; CI runs **spectral** or **lint** rules.
- Implementations **must** match spec; drift = failed build or manual waiver with ticket.

## HTTP method semantics

| Method | Use |
|--------|-----|
| **GET** | Safe, idempotent read; no body with side effects |
| **POST** | Create or non-idempotent action |
| **PUT** | Full replace (idempotent) |
| **PATCH** | Partial update (document merge semantics) |
| **DELETE** | Remove (idempotent when repeated) |

## Status codes

| Code | When |
|------|------|
| **200** | OK with body |
| **201** | Created — `Location` header when applicable |
| **204** | Success, no content |
| **400** | Malformed request |
| **401** | Unauthenticated |
| **403** | Authenticated but forbidden |
| **404** | Resource not found (avoid leaking existence of protected resources where applicable) |
| **409** | Conflict (e.g. duplicate, state machine violation) |
| **422** | Semantic validation failure |
| **429** | Rate limited |
| **500** | Server error |

## Content negotiation

- **Default**: `application/json; charset=utf-8`.
- **406** if `Accept` cannot be satisfied; **415** for unsupported `Content-Type` on bodies.

## Rate limiting

- Return **`429`** with `Retry-After` (seconds or HTTP-date).
- Expose **`X-RateLimit-Limit`**, **`X-RateLimit-Remaining`**, **`X-RateLimit-Reset`** when product supports it.

## Idempotency

- **POST** that creates money movement or duplicates: require **`Idempotency-Key`** header; store key → response for TTL window.
- Document **idempotency** scope and replay behavior in OpenAPI.

## Security transport

- **HTTPS only** in production; **HSTS** at edge; redirect HTTP → HTTPS.

## Documentation

- Every endpoint: **summary**, **auth** requirements, **request/response** schemas, **examples**, **error codes**.
