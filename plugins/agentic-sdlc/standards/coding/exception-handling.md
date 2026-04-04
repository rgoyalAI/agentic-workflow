# Exception and Error Handling

This document defines how errors MUST be modeled, propagated, logged, and translated at system boundaries. It applies to all services, libraries, and test code that exercises production paths.

---

## Universal principles (all languages)

1. **Fail fast**: Validate preconditions at entry points with guard clauses. Reject invalid state before deep call stacks obscure the origin.
2. **Never swallow exceptions silently**: Empty `catch {}`, `except: pass`, or log-only handlers that discard the failure without rethrow, conversion, or documented intentional suppression are forbidden except in narrowly scoped, documented shutdown paths.
3. **Never use exceptions for control flow**: Do not throw/catch to implement normal branches (e.g., “try parse, catch to mean invalid”). Use result types, optionals, or validation APIs instead.
4. **Context in error messages**: Every error surfaced or logged MUST explain what failed, with what inputs (sanitized), and why—without leaking secrets or PII.
5. **Classify errors**:
   - **Business/domain**: Expected outcomes (e.g., insufficient balance)—map to appropriate HTTP/client codes.
   - **Validation**: Client fault—field-level detail where safe.
   - **Infrastructure**: Transient (timeouts, throttling)—retry with backoff where appropriate.
   - **System**: Unexpected bugs—log full detail server-side; return generic messages to clients.
6. **Log at the appropriate level**: WARN for expected business conflicts; ERROR for system/unexpected failures; DEBUG/INFO only when diagnostics are needed without noise.
7. **Correlation IDs**: Include correlation/request IDs in all error logs and structured log fields for traceability across services.

---

## Language-specific patterns

| Language | Error Model | Key Pattern | Anti-Pattern to Avoid |
|----------|------------|-------------|----------------------|
| Java / Spring | Checked + unchecked exceptions | `@ControllerAdvice` global handler, custom exception hierarchy (`BusinessException`, `NotFoundException`, `ValidationException`), translate to HTTP status codes at boundary | Catching `Exception` broadly, throwing `RuntimeException` without subclassing, `catch` with only log-and-rethrow |
| Python | Exception classes | Custom exception hierarchy, `try/except/else/finally`, `@retry` decorators for transient failures, `raise from` for chained context | Bare `except:`, `except Exception as e: pass`, returning `None` for errors |
| Go | Explicit `error` return values | Sentinel errors (`var ErrNotFound = errors.New(...)`), `fmt.Errorf("context: %w", err)` wrapping, `errors.Is()`/`errors.As()` checking, `errors.Join()` for multi-errors | Returning `nil, nil` for missing resources, `panic()` for business errors, ignoring returned errors (`_ = fn()`) |
| C# / .NET | Exception classes + Result pattern | Global middleware (`UseExceptionHandler`), `Result<T>` / `OneOf<T>` for expected failures, exceptions for unexpected, guard clauses at method entry, exception filters (`when` clause) | `catch (Exception)` everywhere, sync-over-async (`.Result`, `.Wait()`), catch-and-log-only without rethrow |
| TypeScript | Error classes + union types | Custom error classes extending `Error`, discriminated unions for expected outcomes, `try/catch` at boundaries only, error boundary components (React) | `catch (e: any)`, swallowing Promise rejections, no `.catch()` on async chains |

---

## Implementation guidance

### Java / Spring

- Centralize HTTP mapping in `@ControllerAdvice` with one handler per exception type or category.
- Use typed exceptions for domain cases; avoid raw `RuntimeException` in application code.
- Preserve cause chains when wrapping (`initCause` or constructor chaining).

### Python

- Subclass from domain base exceptions (`AppError`) for consistent handling.
- Use `raise NewError(...) from e` to preserve context when translating errors.
- For retries, scope to known transient exceptions; do not blanket-retry all `Exception` types.

### Go

- Define package-level sentinel errors for comparisons with `errors.Is`.
- Wrap with `%w` only when callers need `errors.Unwrap`; use `%v` for display-only wrapping.
- Document whether functions return `(nil, nil)`—generally avoid for “not found”; return `ErrNotFound` instead.

### C# / .NET

- Prefer `async` all the way; never block on `Task` in library or ASP.NET request code.
- Use `Result<T>` or similar for recoverable failures; reserve exceptions for invariant violations and infrastructure faults.

### TypeScript

- Narrow `catch` clauses: `instanceof` checks or type guards before accessing properties.
- For React, use error boundaries for subtree failures; route-level handlers for API errors.
- Always attach `.catch()` or `try/await` to promise chains that can reject.

---

## Logging checklist

| Item | Requirement |
|------|-------------|
| Correlation ID | Present on every ERROR/WARN for failed requests |
| Stack traces | Logged server-side for unexpected errors only |
| Client response | No stack traces or internal paths |
| Retry safety | Idempotency keys or documented duplicate behavior for retried operations |

---

## Example: layered error (conceptual)

```text
Domain: InsufficientFundsException → HTTP 409 + business message
Validation: FieldValidationException → HTTP 400 + field errors
Infrastructure: TransientTimeoutException → HTTP 503 + retry-after when applicable
System: UnexpectedException → HTTP 500 + generic message + ERROR log with trace ID
```

Review MUST flag broad catches, empty handlers, exception-driven control flow, and missing correlation context on failure paths.

---

## Boundary translation (HTTP and RPC)

Map internal classifications to stable wire contracts. Example HTTP mapping (adjust to your API standard):

| Internal class | Typical HTTP | Client body |
|----------------|--------------|-------------|
| Validation | 400 Bad Request | Field-level errors, no stack trace |
| Authentication | 401 Unauthorized | Generic message |
| Authorization | 403 Forbidden | No resource existence leak |
| Not found | 404 Not Found | Generic or opaque identifier |
| Conflict / duplicate | 409 Conflict | Business-safe message |
| Rate limit | 429 Too Many Requests | `Retry-After` when applicable |
| Transient infrastructure | 503 Service Unavailable | Retry guidance if idempotent |

For **gRPC**, prefer `INVALID_ARGUMENT`, `NOT_FOUND`, `PERMISSION_DENIED`, `UNAVAILABLE` with structured `details`—never put stack traces in `DebugInfo` to untrusted peers.

---

## Retries, idempotency, and partial failure

- **Retries**: Only for **idempotent** operations or those protected by **idempotency keys**. Classify exceptions as retryable vs fatal before retry loops.
- **Exponential backoff + jitter** for infrastructure faults; cap maximum attempts and surface exhaustion as a classified error.
- **Batch APIs**: Define whether **all-or-nothing** or **per-item errors** apply; return structured partial failure (e.g., item index + error code) instead of a single opaque failure when the contract allows.

---

## Observability beyond logs

| Signal | Practice |
|--------|----------|
| Metrics | Counters for error types; histograms for retry counts |
| Traces | Mark spans with error=true and exception type (sanitized) |
| Alerts | Page on sustained 5xx or dependency error rate SLO burn |

Never include **passwords**, **tokens**, or **full card numbers** in error messages or exception `toString()` output.

---

## Language snippets (patterns)

**Java — preserve cause:**

```java
throw new OrderNotFoundException(orderId, cause);
```

**Python — chain exceptions:**

```python
except ValueError as e:
    raise OrderValidationError("invalid line items") from e
```

**Go — wrap and check:**

```go
if err != nil {
    return fmt.Errorf("load order %s: %w", id, err)
}
```

**TypeScript — narrow unknown:**

```typescript
} catch (e: unknown) {
  if (e instanceof HttpError) { ... }
  throw e;
}
```

---

## Review checklist (errors)

| # | Check |
|---|--------|
| E1 | No empty catches; documented rationale if suppression exists |
| E2 | Errors classified; HTTP/RPC mapping consistent |
| E3 | Correlation ID on WARN/ERROR logs |
| E4 | No exception-based control flow for happy path |
| E5 | Go: all errors handled or explicitly documented |
| E6 | TS/JS: promises have rejection handlers |

These checks complement `security` and `logging` standards: secrets MUST NOT appear in client-visible errors.

---

## User-facing vs operator-facing messages

| Audience | Content |
|----------|---------|
| End user / API client | Safe, actionable, no internals |
| Operator / SRE | Correlation ID, service name, sanitized context |
| Developer (logs) | Stack trace for unexpected only |

**Localization**: externalize user messages; keep **error codes** stable for client branching.

---

## Exception safety and RAII (C++ interop / JNI)

When native code is involved:

- Preserve **resource cleanup** in `finally` or destructors.
- Do not throw across JNI boundaries without translation—**document** JNI exception handling.

---

## Spring specifics

- Use **`@ResponseStatus`** or `ResponseEntityExceptionHandler` consistently.
- Map **`MethodArgumentNotValidException`** to field errors without duplicating validation logic.
- For **WebFlux**, use `onErrorResume` with the same classification as MVC.

---

## Python framework notes

- **FastAPI** `HTTPException` for simple cases; custom exceptions for domain mapping in exception handlers.
- **Django**: middleware for unhandled exceptions; return HTML vs JSON based on `Accept` header.

---

## Go HTTP handlers

- Translate `error` to `http.Status*` in a **single** helper per service to avoid inconsistent mappings.
- Log **wrapped** errors server-side; send **opaque** IDs to clients for 500s.

---

## Resilience patterns (related)

- **Circuit breaker**: open on sustained failures; half-open probe with limited traffic.
- **Bulkhead**: isolate thread pools per dependency to prevent total outage.

These belong in **infrastructure** code; domain layer stays exception/error-pure.

---

## Testing error paths

- **Unit tests** MUST cover: validation failure, not found, conflict, and dependency timeout mocks.
- **Contract tests** verify HTTP status and error **schema** for public APIs.

Neglected error tests are a top source of **500** responses in production for edge cases.
