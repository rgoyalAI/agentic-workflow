# Go — cmd / internal / pkg

Go community layout keeps **entry points thin**, **application code private** under `internal/`, and optionally **reusable libraries** under `pkg/`. This matches the Go tooling expectations and enables clear dependency boundaries.

## Layout

```
cmd/
└── api/
    └── main.go                      # Wires config, logger, HTTP server, graceful shutdown
internal/
├── config/                          # Viper, envconfig, or flag parsing — validated at startup
├── handler/                         # HTTP handlers (chi/echo/gin/gorilla) — parse, call service, write response
├── middleware/                      # Auth, logging, recovery, request ID, metrics
├── service/                         # Business logic; interfaces for repositories
├── repository/                      # DB, cache, external APIs — implements service ports
├── model/                           # Domain structs (may differ from persistence DTOs)
└── dto/                             # API request/response structs, JSON tags
pkg/                                 # Optional: only if reused by multiple binaries
├── logger/
└── validator/
migrations/                          # goose, golang-migrate SQL files, or embed
api/
└── openapi.yaml                     # Source of truth or generated from code — pick one workflow
test/                                # Integration tests, testdata/, httptest helpers
```

## cmd/

- **`main.go`** should: load config, build logger, construct **dependencies** (repos → services → handlers), register routes, run server with **signal-aware shutdown**.
- **No business logic** in `main` beyond wiring — keep functions small and testable.

## internal/

- Code under **`internal/`** cannot be imported by other modules' packages (compiler-enforced when publishing as a module to others — idiomatic for application code).
- **`handler/`**: Translate HTTP to service calls; validate content-type and basic input; **never** embed SQL or domain rules.
- **`service/`**: Transactions, policies, orchestration; accept **context.Context** as first parameter on exported methods.
- **`repository/`**: Implement interfaces defined in `service` or a small `ports` package if you prefer hexagonal naming.

## pkg/

- Use **`pkg/`** only for code that is **stable** and potentially imported by **another repository** or second binary in the same repo. If only `cmd/api` uses it, keep it in `internal/`.

## API contract

- **`api/openapi.yaml`**: Single OpenAPI 3 document; CI validates it; server implementation must match (or codegen from spec with review).

## Migrations

- **`migrations/`**: Numbered SQL files (`000001_init.up.sql`, `.down.sql`) via **golang-migrate** or **goose**; run in deploy pipeline before or alongside rollout (document ordering).

## Testing

- **`test/`** or `internal/.../*_test.go` colocated: unit tests next to packages; integration tests under `test/integration` with build tag `integration`.
- Use **`httptest`** for handlers; **sqlmock** or real DB in Docker for repositories.

## Key rules

1. **`cmd/`** — thin entry points only.
2. **`internal/`** — all private application code; handlers do not contain business logic.
3. **Context propagation** — `context.Context` on I/O boundaries.
4. **Errors** — wrap with `%w` for tracing; map to HTTP in handlers consistently.
5. **No global mutable state** for request-scoped data — use middleware + request context.

## Anti-patterns

- Putting SQL in handlers or `main.go`.
- Exporting everything from `internal` packages unnecessarily — keep surface small.
- Skipping OpenAPI drift checks — leads to undocumented breaking changes.
