# Quarkus Patterns for Agentic SDLC

Quarkus optimizes Java for containers and Kubernetes with fast startup, low memory, and optional native compilation. This guide covers CDI, reactive REST, persistence, testing, and native workflows suitable for automated pipelines.

## CDI and Application Structure

Quarkus uses **ArC** (CDI-lite). Prefer `@ApplicationScoped` for services; avoid unnecessary `@Singleton` unless you need eager init.

```java
@ApplicationScoped
public class InventoryService {

    @Inject
    InventoryRepository repository;

    public Uni<StockLevel> getLevel(String sku) {
        return repository.findBySku(sku);
    }
}
```

Use `@Inject` constructor injection when you need explicit test doubles. Keep REST resources thin: validate input, delegate to services, map responses.

## RESTEasy Reactive

Prefer **RESTEasy Reactive** (`quarkus-resteasy-reactive`) for non-blocking I/O. Return `Uni<T>` / `Multi<T>` from Mutiny for async pipelines.

```java
@Path("/items")
@Produces(MediaType.APPLICATION_JSON)
public class ItemResource {

    @Inject
    ItemService items;

    @GET
    @Path("/{id}")
    public Uni<ItemDto> get(@PathParam String id) {
        return items.findById(id).map(ItemDto::from);
    }
}
```

Blocking JDBC is still usable; for high concurrency, combine reactive routes with non-blocking clients (`quarkus-rest-client-reactive`).

### Client calls and timeouts

Configure reactive REST clients with connect/read timeouts and failure mapping so pipelines do not hang under load:

```properties
quarkus.rest-client.catalog-api.url=${CATALOG_BASE_URL}
quarkus.rest-client.catalog-api.connect-timeout=2000
quarkus.rest-client.catalog-api.read-timeout=5000
```

Map HTTP error codes to domain exceptions in the service layer; avoid leaking upstream bodies in API responses.

## Panache ORM

**Hibernate ORM with Panache** reduces boilerplate: `PanacheEntity` / `PanacheRepository` for active record or repository style.

```java
@ApplicationScoped
public class ProductRepository implements PanacheRepository<Product> {

    public List<Product> findActive() {
        return list("active = ?1", true);
    }
}
```

Use **named queries** or Panache’s fluent API; avoid string concatenation for dynamic SQL—use parameters to prevent injection.

### Transactions and boundaries

Use **`@Transactional`** on service methods that mutate multiple entities. Keep resources free of transaction annotations when services orchestrate persistence—this preserves a single transactional boundary per use case.

## GraalVM Native Image

Add `quarkus.native.enabled=true` for native builds in CI (requires GraalVM or Mandrel).

```bash
./mvnw package -Pnative
# or
./gradlew build -Dquarkus.package.type=native
```

Native image benefits: fast cold start and smaller RSS for serverless and K8s scale-to-zero. Trade-offs: longer compile times, reflection configuration for some libraries—use Quarkus extensions when possible.

`application.properties`:

```properties
quarkus.native.additional-build-args=--initialize-at-run-time=com.example.NativeHints
```

## Dev Services

**Dev Services** auto-start Testcontainers-backed dependencies in dev/test when no connection URL is set (e.g., PostgreSQL, Kafka).

```properties
quarkus.datasource.devservices.enabled=true
%prod.quarkus.datasource.jdbc.url=${DATABASE_URL}
```

In production profiles, always supply real JDBC URLs and credentials via env vars.

## Configuration and Profiles

Quarkus uses **profile prefixes** with `%profile.`:

```properties
greeting.message=hello
%dev.quarkus.log.level=DEBUG
%prod.quarkus.log.level=INFO
%test.quarkus.datasource.jdbc.url=jdbc:h2:mem:test
```

Use `%test` for test-only settings; keep secrets out of committed files.

## Testing with @QuarkusTest

`@QuarkusTest` boots the full application (or a curated subset) for integration tests.

```java
@QuarkusTest
class ProductResourceTest {

    @Test
    void listReturnsOk() {
        given()
            .when().get("/products")
            .then()
            .statusCode(200);
    }
}
```

Add **REST Assured** (included via `quarkus-junit5` + rest-assured dependency) for HTTP assertions. For pure unit tests of classes without Quarkus, use plain JUnit 5.

## Native Tests (`src/native-test`)

Place tests that must run against the **native executable** under `src/native-test/java`. They validate reflection, serialization, and startup paths not covered by JVM tests.

```bash
./mvnw verify -Pnative
```

Ensure CI runs both JVM `verify` and native profile on release branches.

### Continuous integration layout

Typical pipeline stages for Quarkus services:

1. **Compile and unit test** on JVM (`./mvnw test`).
2. **Integration tests** with `@QuarkusTest` (reuse Dev Services or explicit Testcontainers URLs).
3. **Native image** (optional artifact) on release tags with cached Graal/Mandrel layers.
4. **Container image** build using Quarkus-generated Dockerfiles (`quarkus-container-image-jib` or Dockerfile.jvm).

Record native build time in CI metrics; fail fast when native compile exceeds SLO so agents do not block the queue.

## Observability

Use **`quarkus-micrometer`** + **`quarkus-micrometer-registry-prometheus`** for metrics; expose `/q/metrics` only on internal interfaces in Kubernetes. Correlate logs with **trace IDs** via OpenTelemetry extensions when SLAs require distributed tracing.

## Health and readiness

Enable **`quarkus-smallrye-health`**; implement **`HealthCheck`** for downstream systems (databases, queues). Kubernetes should use **`/q/health/live`** and **`/q/health/ready`** separately so rollouts do not route traffic before dependencies are usable.

## Serialization

Prefer **Jackson** annotations on DTOs for API stability; avoid exposing JPA entities directly from resources. Use **`@JsonProperty`** for backward-compatible renames when clients cannot all migrate simultaneously.

## Packaging and Docker

Use **`quarkus-container-image-docker`** or **Jib** extensions to produce reproducible images tagged with git SHA. Multi-stage builds should use **distroless** or **ubi-minimal** base images; run as non-root. Pass config via env vars—avoid baking secrets into layers.

## Build lifecycle hooks

Use **`@Startup` / `@Shutdown`** methods on beans for bounded initialization (connection warm-up) and graceful teardown. Keep hooks fast; defer heavy work to background tasks with clear failure handling.

## Fault tolerance

Use **SmallRye Fault Tolerance** (`@Timeout`, `@Retry`, `@CircuitBreaker`) on REST clients calling unreliable dependencies. Configure thresholds from config properties per environment—tighter limits in production than in dev.

## Mutiny interop

When bridging blocking code, use **`runSubscriptionOn`** / **`emitOn`** with an executor; avoid blocking the event loop thread. Document thread pools for JDBC and CPU work separately.

## Agentic SDLC Checklist

- REST endpoints return reactive types where async I/O is used downstream.
- Panache repositories keep queries parameterized; schema changes tracked (Flyway/Liquibase extensions).
- `%prod` configuration never relies on Dev Services defaults.
- Native build job runs for services shipped as native images.
- REST Assured covers happy path and 4xx/5xx contracts for new APIs.
