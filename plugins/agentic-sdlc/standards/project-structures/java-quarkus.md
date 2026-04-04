# Java — Quarkus (Feature-Based Layout)

Quarkus favors **imperative or reactive** stacks with **CDI** (`@ApplicationScoped`, `@Inject`) and build-time optimization. Use the **same feature-first grouping** as Spring Boot: capabilities under named packages, not a flat layer hierarchy.

## Suggested layout

```
src/main/java/com/company/project/
├── ProjectApplication.java          # QuarkusMain or javax.ws.rs.Application if needed
├── config/                          # Producers, filters, OpenAPI config
├── common/
│   ├── exception/
│   └── dto/
├── auth/
├── order/
└── payment/
```

Per feature: **Resource** (JAX-RS or Spring Web compatibility layer), **Service**, **Repository** (Panache entity/repository), **Entity**, **DTO records**.

## CDI and Quarkus conventions

- Prefer **`@ApplicationScoped`** for singleton services; **`@RequestScoped`** only when request state is required.
- Use **`@Inject`** constructor injection; avoid field injection in new code.
- **Panache**: `PanacheEntity` / `PanacheRepository` colocated in the feature package; keep persistence details out of resources.

## Configuration (`application.properties`)

Quarkus uses **profile prefixes** for environment-specific values:

```properties
# Base
quarkus.datasource.jdbc.url=${DB_URL:}

# Dev profile
%dev.quarkus.hibernate-orm.database.generation=drop-and-create
%dev.quarkus.log.category."org.hibernate".level=DEBUG

# Prod profile
%prod.quarkus.hibernate-orm.database.generation=none
%prod.quarkus.log.level=INFO
```

- **`%dev.`**, **`%prod.`**, **`%test.`** — explicit overrides; avoid ambiguous defaults.
- Secrets via **environment variables** or Quarkus **Kubernetes secrets** mapping — never commit credentials.

## Resources

```
src/main/resources/
├── application.properties
├── META-INF/resources/              # Static assets if applicable
└── db/migration/                    # Flyway
```

## Native and testing

```
src/test/java/...                    # JVM unit + integration tests
src/native-test/java/...             # Tests that run against native image (@QuarkusIntegrationTest)
```

- Place **GraalVM-sensitive** tests under `src/native-test/` when validating native compilation.
- Use **`@QuarkusTest`** for fast JVM integration tests; native runs in CI on release branches or nightly.

## Key rules

1. **Feature folders** — same mental model as Spring Boot; rename Controller → Resource if using JAX-RS exclusively.
2. **application.properties** — profile-prefixed lines for dev vs prod; document required env vars in README.
3. **Native tests** — `src/native-test/` for scenarios that must pass on substrate VM.
4. **Thin boundaries**: Resources validate input and call services; no business logic in filters except cross-cutting concerns.

## Anti-patterns

- Mixing reactive and imperative stacks in one class without clear boundaries.
- Ignoring native compilation constraints (reflection, dynamic proxies) until release time — use Quarkus extensions and configuration.
