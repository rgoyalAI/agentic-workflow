# .NET Clean Architecture for Agentic SDLC

Clean Architecture separates **Domain** (entities, rules) from **Application** (use cases), **Infrastructure** (I/O, EF Core), and **API** (HTTP). This guide aligns with minimal APIs, MediatR, validation, testing, and cross-cutting concerns for automated SDLC.

## Layer Responsibilities

| Layer | References | Contains |
|-------|------------|----------|
| **Domain** | Nothing outward | Entities, value objects, domain events, interfaces |
| **Application** | Domain | Commands/queries, handlers, DTOs, validators |
| **Infrastructure** | Application, Domain | EF Core, email, file storage, external APIs |
| **API** | Application, Infrastructure (DI only) | Program.cs, endpoints, middleware, auth |

**Dependency rule**: inner layers never depend on outer layers. Infrastructure implements interfaces defined in Application or Domain.

## Project Layout

```
src/
  Domain/
  Application/
  Infrastructure/
  Api/
tests/
  Application.UnitTests/
  Api.IntegrationTests/
```

Register services in **`Infrastructure/DependencyInjection.cs`** and **`Api/Program.cs`** with extension methods (`AddApplication`, `AddInfrastructure`).

## Minimal APIs

Map endpoints explicitly; keep delegates thin—delegate to MediatR or application services.

```csharp
app.MapPost("/api/v1/orders", async (CreateOrderCommand cmd, ISender sender, CancellationToken ct) =>
{
    var id = await sender.Send(cmd, ct);
    return Results.Created($"/api/v1/orders/{id}", new { id });
})
.WithName("CreateOrder")
.WithOpenApi();
```

Use **`Results`** for consistent HTTP responses; add **endpoint filters** for validation or correlation IDs.

### API versioning and OpenAPI

Group related endpoints with **`RouteGroupBuilder`** (`MapGroup("/api/v1")`) and enable **Swashbuckle** or **native OpenAPI** in .NET 9+ so Agentic SDLC agents can diff contracts on each PR.

## MediatR (Commands, Queries, Behaviors)

**Commands** and **queries** are records; handlers live in Application.

```csharp
public sealed record CreateOrderCommand(string CustomerId, IReadOnlyList<OrderLineDto> Lines) : IRequest<Guid>;

public sealed class CreateOrderHandler : IRequestHandler<CreateOrderCommand, Guid>
{
    private readonly IOrderRepository _orders;
    public CreateOrderHandler(IOrderRepository orders) => _orders = orders;

    public async Task<Guid> Handle(CreateOrderCommand request, CancellationToken ct)
    {
        var order = Order.Create(request.CustomerId, request.Lines);
        await _orders.AddAsync(order, ct);
        return order.Id;
    }
}
```

**Pipeline behaviors** for cross-cutting concerns: logging, validation, transactions.

```csharp
public sealed class ValidationBehavior<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        if (!validators.Any()) return await next();

        var ctx = new ValidationContext<TRequest>(request);
        var failures = (await Task.WhenAll(validators.Select(v => v.ValidateAsync(ctx, ct))))
            .SelectMany(r => r.Errors).Where(f => f is not null).ToList();
        if (failures.Count != 0) throw new ValidationException(failures);

        return await next();
    }
}
```

## FluentValidation

Define **`AbstractValidator<T>`** per command in Application.

```csharp
public sealed class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.Lines).NotEmpty();
    }
}
```

Register validators in DI; combine with MediatR validation behavior for fail-fast input checks.

### CQRS boundaries

Use **commands** for writes and **queries** for reads; consider **read models** (DTOs projected in Infrastructure) when reporting queries become heavy—avoid loading full aggregates for list screens.

## Entity Framework Core

**`DbContext`** in Infrastructure; entity configurations via **`IEntityTypeConfiguration<T>`**.

```csharp
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> b)
    {
        b.HasKey(x => x.Id);
        b.OwnsMany(x => x.Lines);
    }
}
```

Use **`dotnet ef migrations add`** / **`dotnet ef database update`** in CI/CD with reviewed migrations. Avoid `EnsureCreated` in production.

### Connection resiliency

Enable **retry on failure** for transient SQL errors in cloud databases and set **command timeouts** explicitly. Use **compiled queries** or projections for hot paths after profiling.

## Dependency Injection Registration

```csharp
// Application
services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(CreateOrderHandler).Assembly));
services.AddValidatorsFromAssembly(typeof(CreateOrderCommandValidator).Assembly);
services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));

// Infrastructure
services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(configuration.GetConnectionString("Default")));
services.AddScoped<IOrderRepository, OrderRepository>();
```

## xUnit and Moq

Unit-test handlers with mocked **`IOrderRepository`**.

```csharp
public sealed class CreateOrderHandlerTests
{
    [Fact]
    public async Task Handle_persists_order()
    {
        var repo = new Mock<IOrderRepository>();
        var handler = new CreateOrderHandler(repo.Object);
        var id = await handler.Handle(new CreateOrderCommand("c1", Array.Empty<OrderLineDto>()), CancellationToken.None);
        repo.Verify(r => r.AddAsync(It.IsAny<Order>(), It.IsAny<CancellationToken>()), Times.Once);
    }
}
```

Integration tests: **`WebApplicationFactory<Program>`** with Testcontainers for SQL if needed.

### Test containers and auth

When testing secured minimal APIs, replace **`IAuthenticationHandler`** or use **`WebApplicationFactory` customizations** to inject test tokens. Keep test identity fixtures in a single helper to avoid duplicated JWT plumbing.

## Exception Handling Middleware

Map domain exceptions to HTTP status codes; log unexpected errors with correlation ID.

```csharp
public sealed class ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> log)
{
    public async Task Invoke(HttpContext ctx)
    {
        try { await next(ctx); }
        catch (ValidationException ex)
        {
            ctx.Response.StatusCode = StatusCodes.Status400BadRequest;
            await ctx.Response.WriteAsJsonAsync(new { errors = ex.Errors });
        }
        catch (NotFoundException)
        {
            ctx.Response.StatusCode = StatusCodes.Status404NotFound;
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Unhandled");
            ctx.Response.StatusCode = StatusCodes.Status500InternalServerError;
        }
    }
}
```

### Problem Details (`RFC 7807`)

Return **`ProblemDetails`** for machine-readable errors; include **`traceId`** from `HttpContext.TraceIdentifier` for support correlation without exposing internal exception messages.

## Observability and health

Add **`AddHealthChecks()`** with EF Core and external dependency checks. Export **OpenTelemetry** traces/metrics when SLAs require end-to-end visibility across Agentic SDLC services.

## Configuration and options pattern

Bind **`IConfiguration`** to **strongly typed options** with **`IOptions<T>`** / **`IOptionsMonitor<T>`** for reloadable settings. Validate options at startup with **`IValidateOptions<T>`** or **DataAnnotations** so misconfiguration fails fast in CI/deploy.

## Authorization

Keep **authorization rules** close to handlers: policy-based authorization with **`IAuthorizationService`** for resource-based checks. Do not duplicate role checks inside MediatR handlers unless the rule is domain-specific—document the split for security reviews.

## Mapping and DTOs

Use **Mapster** or **AutoMapper** profiles to translate between Domain entities and API DTOs—keep mapping in Application or API layers, not in Domain. Version DTOs when breaking JSON contracts; keep old endpoints during deprecation windows.

## Background processing

Offload long work to **Hangfire**, **Azure Service Bus**, or **MassTransit** consumers. Handlers should be idempotent with deduplication keys; store correlation IDs on domain events for replay diagnostics.

## Agentic SDLC Checklist

- Domain free of EF attributes if purity matters; use fluent config in Infrastructure.
- Every command/query has validator and handler tests for critical paths.
- EF migrations reviewed in PRs; no breaking schema without data strategy.
- MediatR behaviors cover validation, logging, and optional transactions.
- API layer exposes OpenAPI; integration tests assert status codes and error shape.
