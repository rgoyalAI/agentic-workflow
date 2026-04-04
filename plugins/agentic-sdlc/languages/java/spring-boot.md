# Spring Boot Patterns for Agentic SDLC

This guide describes conventions for Spring Boot services in automated SDLC pipelines: predictable structure, testable boundaries, and safe defaults for security and observability.

## Project Structure (Feature-Based Packages)

Organize by **vertical slice** (feature), not purely by technical layer. Each feature owns its API, application services, and persistence adapters.

```
src/main/java/com/example/product/
  ProductApplication.java
  common/                    # shared kernel: exceptions, validation, mappers
  catalog/
    api/
      CatalogController.java
      dto/
        CatalogResponse.java
    application/
      CatalogService.java
      port/
        CatalogRepository.java   # interface (hexagonal)
    domain/
      Product.java
    infrastructure/
      persistence/
        JpaProductRepository.java
        ProductEntity.java
        ProductMapper.java
```

**Rules**

- Controllers depend on application services, not repositories directly.
- Domain types stay framework-agnostic; JPA entities live in `infrastructure`.
- Cross-feature reuse goes through `common` or explicit shared modules—avoid cyclic dependencies.

## Bean Patterns

Use stereotype annotations consistently:

| Annotation    | Role |
|---------------|------|
| `@RestController` | HTTP boundary; thin—maps DTOs, delegates to services |
| `@Service`        | Use cases, transactions (`@Transactional` at service level) |
| `@Repository`     | Spring Data interfaces or custom `@Repository` implementations |

```java
@Service
@Transactional(readOnly = true)
public class OrderService {

    private final OrderRepository orders;
    private final PaymentClient payments;

    public OrderService(OrderRepository orders, PaymentClient payments) {
        this.orders = orders;
        this.payments = payments;
    }

    @Transactional
    public OrderView placeOrder(PlaceOrderCommand cmd) {
        // ...
    }
}
```

Prefer **constructor injection**; avoid `@Autowired` on fields. Keep controllers free of business rules.

## Spring Security

Define a single `SecurityFilterChain` bean (Spring Security 6+). Centralize CORS and CSRF policy.

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                .ignoringRequestMatchers("/api/public/**"))
            .cors(Customizer.withDefaults())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health", "/api/public/**").permitAll()
                .anyRequest().authenticated())
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration cfg = new CorsConfiguration();
        cfg.setAllowedOrigins(List.of("https://app.example.com"));
        cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
        cfg.setAllowedHeaders(List.of("*"));
        cfg.setAllowCredentials(true);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", cfg);
        return source;
    }
}
```

- **APIs**: Often disable CSRF for pure JSON APIs protected by JWT; use CSRF for cookie-based browser sessions.
- **CORS**: Never use `*` with credentials; list explicit origins in production.

## Data Access

- **JPA**: Prefer `Optional` returns, `@EntityGraph` or fetch joins to avoid N+1 queries.
- **Spring Data**: Repository interfaces per aggregate; avoid “god” repositories.
- **Migrations**: Use **Flyway** (or Liquibase); never rely on `ddl-auto=update` in production.

`src/main/resources/db/migration/V1__init.sql` — versioned, reviewed like application code.

```yaml
spring:
  jpa:
    hibernate:
      ddl-auto: validate
  flyway:
    enabled: true
    locations: classpath:db/migration
```

## Testing

- **Testcontainers**: Real Postgres/Redis/Kafka in CI for integration tests.

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class OrderIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
    }

    @Test
    void contextLoads() { /* ... */ }
}
```

- **`@WebMvcTest(OrderController.class)`**: Slice test with `MockMvc`; mock `OrderService`.
- **`MockMvc`**: Assert status, JSON body, and security rules without starting full servlet container when possible.

```java
@WebMvcTest(controllers = OrderController.class)
@Import(SecurityConfig.class)
class OrderControllerTest {

    @Autowired MockMvc mvc;
    @MockBean OrderService orders;

    @Test
    void getOrder_returns404() throws Exception {
        when(orders.findById("x")).thenReturn(Optional.empty());
        mvc.perform(get("/api/orders/x"))
            .andExpect(status().isNotFound());
    }
}
```

## Profiles

Use `application-{profile}.yml` for environment-specific overrides. Keep secrets out of files—use env vars or Spring Cloud Config / external secret stores.

```yaml
# application.yml
spring:
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:dev}

---
spring:
  config.activate.on-profile: dev
logging.level.com.example: DEBUG

---
spring:
  config.activate.on-profile: prod
logging.level.root: WARN
```

## Actuator and Health

Expose **health** and **readiness** for orchestrators; protect sensitive endpoints.

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      probes:
        enabled: true
```

Custom health indicators implement `HealthIndicator` for dependencies (DB, queues).

## Exception Handling

Use `@ControllerAdvice` for consistent problem responses (RFC 7807-style or your API envelope).

```java
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    ResponseEntity<ProblemDetail> notFound(NotFoundException ex, HttpServletRequest req) {
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        pd.setInstance(URI.create(req.getRequestURI()));
        return ResponseEntity.status(404).body(pd);
    }
}
```

Never leak stack traces or internal messages to clients in production.

## DTOs as Java Records (Java 21+)

Use **records** for immutable API contracts and command objects.

```java
public record CreateOrderRequest(
    @NotBlank String customerId,
    @NotEmpty List<OrderLineRequest> lines
) {}

public record OrderLineRequest(
    @NotBlank String sku,
    @Positive int quantity
) {}
```

Validate at the boundary with `@Valid`; map to domain types inside the service layer.

## Build Commands

**Maven**

```bash
./mvnw -q -DskipTests package
./mvnw test
./mvnw verify -Pintegration-tests
```

**Gradle**

```bash
./gradlew build
./gradlew test
./gradlew integrationTest
```

Pin the wrapper and plugin versions in CI for reproducible Agentic SDLC runs.

## Agentic SDLC Checklist

- Feature packages with clear inward dependencies.
- Security filter chain reviewed for each new public route.
- Flyway migration for every schema change.
- Integration test for critical paths; slice tests for new controllers.
- Actuator health verified in deployment manifests.
