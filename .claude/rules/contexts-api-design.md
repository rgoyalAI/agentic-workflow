---
paths:
  - "openapi*.yml"
  - "openapi*.yaml"
  - "openapi*.json"
  - "swagger*.yml"
  - "swagger*.yaml"
  - "swagger*.json"
  - "**/*.graphql"
---

# Context: API Design

## When to use
- `api_detected == true`

## How to apply
- Validate inputs at the boundary (schema/DTO validation) and reject invalid requests with a consistent 4xx error envelope.
- Use consistent response envelopes and a standard error shape that always includes a `correlation_id`.
- Document APIs using the repo's chosen standard (e.g., OpenAPI/Swagger or GraphQL schema); do not leave endpoints undocumented.
- For list endpoints, implement pagination using the repo's conventions (page/limit/offset or cursor) and enforce maximum limits.
- For mutating operations, prefer idempotency where the domain supports it; document any non-idempotent behavior.

## What not to do
- Do not introduce breaking changes without versioning/compatibility strategy.
- Do not leak internal errors, stack traces, or secrets in error responses.
- Do not accept raw/unchecked payloads into business logic.

