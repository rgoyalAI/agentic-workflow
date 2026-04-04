# Input Validation

This document defines how all **external and boundary** data MUST be validated before use: APIs, queues, files, third-party callbacks, and configuration.

---

## Universal principles

1. **Validate at every system boundary**: HTTP/RPC handlers, message consumers, batch importers, webhooks, CLI args, and deserialized environment/config payloads.
2. **Schema-based validation**: Use established validation libraries—not ad-hoc regex scattered through code—for structural and constraint checks.
3. **Validation order**: Type → format → range → length → **business rules** (dependencies on other fields, cross-record constraints).
4. **Fail fast**: Reject invalid input before expensive work; return structured errors with field-level detail when safe.
5. **Never trust client-side validation alone**: Browser and mobile checks are UX only; the server (or authoritative worker) MUST re-validate.

---

## Per-language reference

| Language | Validation Library | Key Pattern |
|----------|-------------------|-------------|
| Java / Spring | `jakarta.validation` (Bean Validation 3.0), `@Valid`, custom `ConstraintValidator` | Annotate DTOs with `@NotNull`, `@Size`, `@Pattern`; validate at controller boundary; custom validators for business rules |
| Python / FastAPI | Pydantic v2 `BaseModel`, `Field(...)`, custom validators | Define request/response models with type hints + constraints; auto-validated by framework |
| Python / Django | Django Forms, DRF Serializers with `validate_<field>()` | Serializer-level validation for API, Form validation for web |
| Go | `go-playground/validator`, custom middleware | Struct tags (`validate:"required,email"`), validate at handler entry, return structured error map |
| C# / .NET | FluentValidation, `DataAnnotations` | `AbstractValidator<T>` with chained rules, registered in DI, invoked in pipeline behavior (MediatR) |
| TypeScript | Zod, Yup, class-validator | `z.object({...}).parse(input)` at route handler entry; inferred TypeScript types from schema |

---

## Security and UX

- **Normalize** encodings (UTF-8) at the boundary; reject invalid sequences per policy.
- **Allowlists** over denylists for enums, MIME types, and redirect URLs when security-relevant.
- **Rate-limit** expensive validation paths (e.g., regex on large strings) to prevent ReDoS—prefer library validators with bounded behavior.
- **Log** validation failures at WARN with correlation ID—not full payloads containing secrets.

---

## Example shapes (illustrative)

**Structured error response** (conceptual):

```json
{
  "code": "VALIDATION_FAILED",
  "message": "One or more fields are invalid",
  "fields": {
    "email": ["must be a valid email address"],
    "quantity": ["must be between 1 and 100"]
  }
}
```

**FastAPI / Pydantic**: model defines constraints once; OpenAPI reflects them automatically.

**Zod**: `safeParse` for non-throwing flows; map issues to HTTP 400 in a single middleware.

---

## Review checklist

| Check | Pass criteria |
|-------|----------------|
| Boundary coverage | Every ingress path uses schema or equivalent validation |
| Business rules | Documented in validators or domain services—not only in UI |
| Error shape | Consistent, no stack traces to clients for validation |

Violations: unchecked `any`/`interface{}` at boundaries, manual string checks duplicating schema rules, trusting webhook signatures without cryptographic verification (see `cryptography.md`).

---

## Boundary inventory (what counts as “input”)

| Source | Validate |
|--------|----------|
| REST/JSON body | Yes — DTO + schema |
| Query/path params | Yes — coercion and range |
| Headers (`Content-Type`, auth) | Yes — format and presence per route |
| Message queue payloads | Yes — same rigor as HTTP |
| Webhook bodies | Yes — plus signature/HMAC per `cryptography.md` |
| Uploaded files | Extension/MIME allowlist, size cap, content scanning policy |
| Environment variables at startup | Schema (ports, URLs, feature flags) |

---

## Cross-field and async validation

- **Cross-field rules** (“end date after start date”) belong in validators or domain services—keep schemas declarative where possible.
- **Database-backed rules** (“username unique”) require queries—run **after** cheap checks; handle races with unique constraints and translate to HTTP 409.
- **Caching**: invalidated rule results must not skip re-validation on mutating requests.

---

## Framework-specific tips

**Spring**: combine `@Valid` on controller parameters with groups for create vs update DTOs.

**FastAPI**: use `model_config` and `field_validator` for reusable normalizers (trim whitespace, casefold emails).

**Django REST**: override `validate` for object-level constraints; use `serializer.is_valid(raise_exception=True)`.

**Go**: centralize `validator` engine setup; map validation tags to HTTP 400 consistently.

**FluentValidation**: `RuleForEach` for collections; async validators only when necessary—watch thread-pool usage.

**Zod**: `.strict()` to reject unknown keys when security-relevant; use `.transform` for normalization.

---

## Review checklist (validation)

| # | Check |
|---|--------|
| V1 | Every ingress path listed in boundary inventory |
| V2 | Schema library used; no duplicate regex islands |
| V3 | Business rules after structural validation |
| V4 | Errors structured; no stack traces to clients |
| V5 | File uploads bounded and scanned per policy |

**Internationalization**: error codes stable; messages may be localized separately—do not rely on English substring matching in clients.

---

## Sanitization vs validation

- **Validation**: reject invalid input.
- **Sanitization**: transform dangerous input (HTML escape, trim) **only** when the product spec requires storing/displaying user content—prefer validation + safe templating.

Never rely on sanitization alone for **SQL** or **shell** injection—use **parameterized** APIs.

---

## Numeric and monetary input

- Use **decimal** types for money; never `float` for currency.
- Define **scale and precision** explicitly in schemas (e.g., `Decimal` with quantize).
- Reject **negative** quantities where business rules forbid them at schema layer.

---

## Date and time

- Accept **ISO 8601** with explicit offset or `Z` for UTC.
- Reject ambiguous **local** times without zone when events cross DST—require offset or zone ID.

---

## Content types and encodings

- Reject unexpected `Content-Type` for bodies (e.g., JSON-only routes).
- Enforce **max body size** at gateway and framework.

---

## GraphQL (if used)

- **Depth/complexity** limits to prevent expensive queries.
- **Pagination** on lists; validate variable types strictly.

---

## Versioned APIs

- When validation rules **tighten**, use API **versioning** to avoid breaking existing clients—or accept both shapes during migration with explicit deprecation headers.

---

## Review checklist (validation extended)

| # | Check |
|---|--------|
| V6 | Money uses decimal types |
| V7 | Dates include timezone or UTC |
| V8 | Body size and content-type enforced |
| V9 | Injection risks use parameterized APIs |

Input validation is the first line of defense—pair with **`cryptography.md`** and **`security`** checklists for defense in depth.
