# Naming Conventions

This document defines cross-cutting naming rules and per-language conventions. All generated and reviewed code MUST align with these standards and with existing project conventions where they are stricter.

## Cross-cutting rules

- **Intention-revealing names**: Prefer names that describe purpose and behavior without requiring readers to infer meaning from context alone.
- **No abbreviations** unless they are universally understood in the domain (e.g., `id`, `url`, `http`, `dto`). Avoid project-specific abbreviations that new contributors cannot decode.
- **Follow codebase conventions**: When a repository already establishes patterns (prefixes, suffixes, folder layout), new code must match them; this document is the baseline for greenfield work.
- **No single-letter variables** outside narrow loop iterators (`i`, `j`, `k` in simple loops) and well-established mathematical contexts (e.g., matrix indices in algorithms).
- **No Hungarian notation**: Do not encode types in names (`strName`, `bFlag`). Use the type system and clear nouns/verbs instead.

---

## Per-language reference

| Language | Classes/Types | Methods/Functions | Variables | Constants | Packages/Modules | Files |
|----------|--------------|-------------------|-----------|-----------|-------------------|-------|
| Java | `PascalCase` (nouns) | `camelCase` (verbs) | `camelCase` | `UPPER_SNAKE_CASE` | `com.company.module` (lowercase dots) | `PascalCase.java` |
| Python | `PascalCase` | `snake_case` | `snake_case` | `UPPER_SNAKE_CASE` | `snake_case` | `snake_case.py` |
| Go | `PascalCase` (exported), `camelCase` (unexported) | Same as types | `camelCase` | `PascalCase` or `camelCase` (no `UPPER_SNAKE`) | `lowercase` (single word preferred) | `snake_case.go` |
| C# / .NET | `PascalCase` | `PascalCase` | `camelCase`, `_camelCase` (private fields) | `PascalCase` | `Company.Module` (PascalCase dots) | `PascalCase.cs` |
| TypeScript/React | `PascalCase` (components, classes) | `camelCase` | `camelCase` | `UPPER_SNAKE_CASE` | `kebab-case` (folders) | `PascalCase.tsx` (components), `camelCase.ts` (utils) |
| Angular | `PascalCase` (components, services) | `camelCase` | `camelCase` | `UPPER_SNAKE_CASE` | `kebab-case` | `kebab-case.component.ts` |

### Notes by ecosystem

- **Java**: Type names are nouns (`OrderService`, `PaymentGateway`). Method names are verbs or verb phrases (`calculateTotal`, `findById`). Packages mirror reverse-DNS and stay lowercase with dot separators.
- **Python**: Module names are short, lowercase, and underscore-separated. Class names use PascalCase per PEP 8; module-level “constants” use `UPPER_SNAKE_CASE`.
- **Go**: Exported identifiers start with uppercase; unexported with lowercase. Package names are concise nouns; avoid `util`/`common` as catch-all package names—prefer domain nouns (`auth`, `invoice`).
- **C# / .NET**: Public members use PascalCase. Private fields often use `_camelCase` for clarity in constructors and properties. Namespace segments use PascalCase.
- **TypeScript/React**: React components and their files use PascalCase. Hooks and utilities typically live in `camelCase.ts`. Barrel files (`index.ts`) re-export with stable public names.
- **Angular**: CLI schematics generate `kebab-case` file names with type suffix (`.component.ts`, `.service.ts`). Class names inside remain PascalCase.

---

## Additional rules

### Interfaces

| Language | Convention |
|----------|-------------|
| Java | `FooService` — **no `I` prefix** on interface names |
| C# | `IFooService` — **with `I` prefix** for interfaces |
| Go | No special prefix; use concrete, behavior-oriented names; small interfaces are idiomatic |

### Boolean names

Prefix with **`is`**, **`has`**, **`can`**, or **`should`** so the meaning reads as a predicate:

- Good: `isActive`, `hasPermission`, `canSubmit`, `shouldRetry`
- Avoid: `active`, `permission`, `submit` (ambiguous as booleans)

### Collection names

Use **plural nouns** for collections, arrays, lists, and sets: `users`, `orderItems`, `pendingInvoices`.

For maps, prefer **value-plural** or explicit pair naming: `userIdToProfile`, `ordersByCustomerId`.

### Enums

| Language | Type name | Members |
|----------|-----------|---------|
| Java | `PascalCase` | `UPPER_SNAKE_CASE` |
| C# | `PascalCase` | `PascalCase` (conventional for .NET enums) or team-standard |
| Go | `PascalCase` type | `PascalCase` exported constants in the same block |

Document whether numeric values are stable across API versions if serialized.

### Test methods

| Language | Pattern |
|----------|---------|
| Python | `test_<behavior>_<condition>_<expected>` |
| Java / C# | `should<Behavior>When<Condition>` (e.g., `shouldReturn404WhenOrderMissing`) |
| Go | `Test<Function>_<Scenario>` (table-driven subtests with `t.Run` for cases) |

Keep test names readable in failure output; avoid abbreviations that obscure the scenario.

---

## Examples (correct vs. wrong)

```java
// Java: verb method, noun type, clear variable
public Optional<Order> findOrderById(OrderId orderId) { ... }
```

```python
# Python: snake_case functions and variables
def calculate_line_total(unit_price: Decimal, quantity: int) -> Decimal:
    ...
```

```typescript
// React: PascalCase component file and export
export function OrderSummary(props: OrderSummaryProps) { ... }
```

Violations to flag in review: Hungarian prefixes, vague names (`data`, `info`, `temp` without domain), inconsistent casing within the same language, and interfaces named against the table above.

---

## DTOs, events, and domain artifacts

| Artifact | Naming guidance |
|----------|-----------------|
| Request/response DTOs | Suffix with purpose: `CreateOrderRequest`, `OrderResponse`, `UserProfileDto` (if `Dto` is team-standard) |
| Domain events | Past tense or fact: `OrderPlaced`, `PaymentCaptured` |
| Commands / queries (CQRS) | Imperative for commands: `PlaceOrderCommand`; noun + `Query` for reads: `OrderSummaryQuery` |
| Mappers | `OrderMapper`, `toDomain`, `toPersistence` methods inside dedicated mapper types |
| Factories | `OrderFactory` or `Order.create(...)` static factories—one naming scheme per bounded context |

Avoid redundant words: `OrderData` is usually weaker than `Order` or `OrderSnapshot` unless “data” distinguishes from the aggregate.

---

## Test files and suites

| Language | File naming |
|----------|-------------|
| Java | `OrderServiceTest.java` or `*IT.java` for integration—follow Surefire/Failsafe conventions |
| Python | `test_orders.py` or `test_order_service.py` next to `pytest` discovery rules |
| Go | `order_service_test.go` alongside `order_service.go` |
| C# | `OrderServiceTests.cs` in `*.Tests` projects |
| TypeScript | `order.service.spec.ts` (Angular), `OrderCard.test.tsx` (React + Vitest/Jest) |

**Describe/it blocks** should read as specifications: `describe('OrderService')` with `it('returns empty when no orders exist')`.

---

## Abbreviations and acronyms

- **Allowed when universal**: `id`, `url`, `uri`, `http`, `json`, `api`, `sql`, `csv` (consistent casing per language).
- **Avoid**: team-only abbreviations (`mgr`, `tmp`, `misc`) in public APIs.
- **Casing**: In .NET/Java/TS, use `HttpClient` / `XmlParser` (PascalCase acronyms when short); Python prefers `http_client` with lowercase words.

---

## Review checklist (naming)

| # | Check |
|---|--------|
| N1 | Public identifiers match language column conventions in the master table |
| N2 | Booleans use `is` / `has` / `can` / `should` prefixes |
| N3 | Collections are plural; maps describe relationship |
| N4 | Interfaces follow Java vs C# vs Go rules |
| N5 | Test names encode scenario and expected outcome per language pattern |
| N6 | No Hungarian notation or misleading abbreviations |

When automated linters disagree with this document, **project `AGENTS.md` or repo standards win**—record exceptions in code review rationale.

---

## REST and URL naming (related)

- **Resources** plural nouns: `/orders`, `/orders/{orderId}/items`
- **Actions** as sub-resources or verbs only when RPC-style is approved: `/orders/{id}:cancel`
- **Query params** `snake_case` or `camelCase` per API standard—**one** style per API surface

Path segments often appear in logs—avoid embedding **PII** in resource names.

---

## Database and migration naming

| Object | Convention |
|--------|--------------|
| Tables | `snake_case` plural (`order_items`) |
| Columns | `snake_case` |
| Indexes | `idx_<table>_<cols>` |
| Constraints | `fk_<from>_<to>` |

Align with `database` standards if the repo defines stricter DDL rules.

---

## Logging field names

Use **structured keys** consistent across services: `user_id`, `order_id`, `correlation_id`—match OpenTelemetry semantic conventions where applicable.

---

## Generics and type parameters

- Java / C# / TypeScript: **single uppercase** type parameters (`T`, `TItem`, `TKey`) are acceptable; prefer **descriptive** names for public APIs (`TEntity`).

---

## Feature flags and config keys

- **SCREAMING_SNAKE** for environment variables: `FEATURE_BILLING_V2`
- **Hierarchical** keys for config trees: `billing.retry.maxAttempts`

---

## Glossary alignment

Maintain a **ubiquitous language** glossary per bounded context so `Shipment` vs `Delivery` terms do not drift across modules—naming reviews SHOULD reference it.

Consistent naming is **documentation** that never goes stale when enforced by habit and lint rules.
