# .NET — Clean Architecture + Vertical Slices

ASP.NET Core solutions benefit from **Clean Architecture** dependency rules combined with **vertical slice** organization in the Application layer: each feature is a folder with command/query handlers, validators, and DTOs.

## Solution layout

```
src/
├── Api/
│   ├── Program.cs
│   ├── Endpoints/                   # Minimal APIs or thin controllers grouped by feature area
│   ├── Middleware/
│   └── Extensions/
├── Application/
│   ├── Features/
│   │   ├── Orders/
│   │   │   ├── CreateOrder/
│   │   │   │   ├── CreateOrderCommand.cs
│   │   │   │   ├── CreateOrderHandler.cs
│   │   │   │   └── CreateOrderValidator.cs
│   │   │   └── GetOrderById/
│   │   └── Payments/
│   ├── Common/
│   │   ├── Behaviors/               # MediatR pipeline: logging, validation, transaction
│   │   └── Interfaces/              # IDateTime, ICurrentUser, outbound ports
│   └── DependencyInjection.cs
├── Domain/
│   ├── Entities/
│   ├── ValueObjects/
│   ├── Enums/
│   └── Exceptions/
└── Infrastructure/
    ├── Persistence/
    │   ├── Configurations/          # EF Core fluent config
    │   ├── Migrations/
    │   └── Repositories/
    └── Services/                    # Email, blob, third-party adapters
tests/
├── UnitTests/
├── IntegrationTests/
└── ArchTests/                       # NetArchTest or similar — dependency rules
```

## Dependency rule

- **Domain**: **zero** dependencies on Application, Infrastructure, or Api. Pure C# and domain concepts.
- **Application**: depends on **Domain** only; defines interfaces for infrastructure; implements use cases.
- **Infrastructure**: implements Application ports; references **Application** + **Domain**.
- **Api**: references **Application** + **Infrastructure** (DI registration); minimal logic in endpoints.

## Vertical slices (`Application/Features/`)

- Each **feature subfolder** (`CreateOrder/`) contains **one primary use case** — command/query, handler, validator.
- Shared cross-feature code goes to **`Application/Common/`** — not copy-pasted across slices.

## Api layer

- **`Endpoints/`**: Map routes to MediatR `ISender.Send` or application services; map results to HTTP.
- **`Middleware/`**: correlation ID, exception handling, authentication pipeline.

## Infrastructure

- **EF Core** `DbContext`, configurations, migrations under **`Persistence/`**.
- External systems behind interfaces declared in Application.

## Testing

- **UnitTests**: Handlers with mocked `IOrderRepository`; domain unit tests without mocks where possible.
- **IntegrationTests**: WebApplicationFactory, Testcontainers SQL, full HTTP + DB.
- **ArchTests**: Assert Domain does not reference Infrastructure; Api does not reference Persistence types directly, etc.

## Key rules

1. **Domain has zero dependencies** on frameworks.
2. **Vertical slices in `Features/`** — one folder per use case group; keep handlers cohesive.
3. **ArchTests** enforce layering — run in CI on every PR.
4. **MediatR** (optional but common) keeps controllers/endpoints thin.

## Anti-patterns

- `DbContext` usage inside Api controllers — bypasses Application and breaks testability.
- Anemic Domain with all logic in giant services — balance rich domain vs. pragmatism per project norms.
