# Java — Spring Boot (Feature-Based Package Layout)

This standard defines a **vertical-slice (feature-first)** layout for Spring Boot services. Code is grouped by **business capability**, not by technical layer at the top level. Shared cross-cutting code lives under `common/`.

## Root package

```
src/main/java/com/company/project/
├── ProjectApplication.java          # @SpringBootApplication — single entry, root package only
├── config/                          # Spring @Configuration, Security, OpenAPI, beans
├── common/
│   ├── exception/                   # @ControllerAdvice handlers, domain error mapping
│   └── dto/                         # Shared API envelopes, pagination, problem details
├── auth/                            # Feature: authentication & authorization
├── order/                           # Feature: orders
└── payment/                         # Feature: payments
```

Each **feature folder** (e.g. `order/`) contains everything that belongs to that slice:

| Artifact | Responsibility |
|----------|----------------|
| `*Controller.java` | HTTP mapping, validation trigger, HTTP status; **no** business rules |
| `*Service.java` | Use cases, orchestration, transactions |
| `*Repository.java` | Spring Data interfaces or custom `@Query` |
| `*Entity.java` | JPA entities (persistence model) |
| DTOs (`*Request`, `*Response`, `*View`) | API contracts — **prefer Java `record` types** |

Optional per feature: `mapper/`, `client/` for outbound calls, `policy/` for authorization rules.

## Application class rules

- **One** `@SpringBootApplication` on `ProjectApplication.java` at `com.company.project`.
- Do not scatter `@SpringBootApplication` or duplicate component scans without documented reason.
- Feature packages are discovered automatically when under the main class package.

## Resources layout

```
src/main/resources/
├── application.yml                  # Defaults + shared keys
├── application-dev.yml              # spring.profiles.active=dev
├── application-prod.yml
└── db/
    └── migration/                   # Flyway: V{version}__description.sql
```

Use **Flyway** or **Liquibase** for schema evolution; never hand-apply DDL in production outside migrations.

## Test layout

```
src/test/java/com/company/project/
├── TestcontainersConfig.java        # @TestConfiguration for DB, messaging, etc.
├── auth/
├── order/
│   └── OrderServiceTest.java        # Colocated with feature under test
└── payment/
```

- **Colocate** tests with features (`order/OrderControllerTest`, `order/OrderServiceTest`).
- Use **Testcontainers** for integration tests that need real PostgreSQL, Kafka, etc.
- Keep pure unit tests fast (no container) in the same package with `@ExtendWith(MockitoExtension.class)` or similar.

## Key rules (non-negotiable)

1. **Feature-based packages**, not `controller/`, `service/`, `repository/` at the root.
2. **DTOs as Java `record`** where possible — immutable, clear API surface; map to/from entities in a dedicated layer (mapper or explicit methods).
3. **Migrations** are versioned SQL or Liquibase changesets — sequential, reviewed, deployed with the app.
4. Controllers delegate to services; repositories stay behind services.
5. **Exceptions**: throw domain or service exceptions; translate to HTTP in `common/exception/` via `@ControllerAdvice`.

## Anti-patterns

- Giant `util` packages that become a dumping ground — prefer feature-local helpers or `common/` with narrow scope.
- Entities leaked directly from controllers — always use DTOs/records at the boundary.
- Business logic in `@Repository` implementations beyond query composition.
