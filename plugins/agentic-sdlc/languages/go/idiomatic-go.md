# Idiomatic Go for Agentic SDLC

Go favors simplicity, explicit error handling, and composition. This guide covers errors, concurrency, testing, HTTP, layout, and tooling for production services in automated SDLC pipelines.

## Error Handling

**Errors are values.** Return `error` as the last result; never ignore it without intent.

**Sentinel errors** (package-level `var ErrX = errors.New(...)`) allow `errors.Is` checks across packages.

```go
var ErrNotFound = errors.New("not found")

func Find(ctx context.Context, id string) (*User, error) {
    u, err := repo.Load(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("load user: %w", err)
    }
    if u == nil {
        return nil, ErrNotFound
    }
    return u, nil
}
```

Use **`fmt.Errorf` with `%w`** to wrap errors for `errors.Is` / `errors.As`. At boundaries (HTTP handlers), map wrapped errors to status codes without leaking internals.

### Error types and helpers

Define **`type NotFoundError struct { Resource, ID string }`** with `Error()` when you need structured fields; use **`errors.As`** to extract details for logging while returning generic messages to clients.

```go
type NotFoundError struct { Kind, ID string }
func (e NotFoundError) Error() string { return fmt.Sprintf("%s %s not found", e.Kind, e.ID) }
```

Avoid **`panic`** in libraries; reserve panic for programmer mistakes during startup (misconfiguration).

```go
if errors.Is(err, domain.ErrNotFound) {
    http.Error(w, "not found", http.StatusNotFound)
    return
}
var ve *domain.ValidationError
if errors.As(err, &ve) {
    http.Error(w, ve.Error(), http.StatusBadRequest)
    return
}
```

## Goroutines and Channels

- Prefer **`context.Context`** as the first parameter for cancelable work.
- Do not leak goroutines: ensure sends/receives complete or `ctx` is canceled.
- Use channels for ownership transfer or fan-in/fan-out; mutexes for shared memory.

```go
func worker(ctx context.Context, jobs <-chan Job, out chan<- Result) {
    for {
        select {
        case <-ctx.Done():
            return
        case j, ok := <-jobs:
            if !ok {
                return
            }
            out <- process(j)
        }
    }
}
```

Document expected buffer sizes; unbuffered channels synchronize; buffered channels trade latency for throughput.

## `context.Context`

Pass `ctx` through all public APIs that do I/O. Derive timeouts at the edge:

```go
ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
defer cancel()
u, err := svc.GetUser(ctx, id)
```

Never store contexts in structs except for short-lived request-scoped types (e.g., server stream adapters).

### Cancellation and deadlines

Propagate parent context from **`http.Request.Context()`** in handlers. When calling external APIs, prefer **`context.WithTimeout`** per request rather than package-level timeouts—this keeps Agentic SDLC load tests honest about tail latency.

## Table-Driven Tests

Use **`t.Run`** for subtests and shared setup; name cases clearly for CI output.

```go
func TestNormalizeEmail(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  string
    }{
        {"trims", "  A@B.COM ", "a@b.com"},
        {"empty", "", ""},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := NormalizeEmail(tt.input)
            if got != tt.want {
                t.Fatalf("got %q want %q", got, tt.want)
            }
        })
    }
}
```

Use **`testing/quick`** or **fuzzing** (`go test -fuzz`) for parsers and validators.

### Golden files and benchmarks

Place large expected outputs in **`testdata/`** (ignored as packages). Use **`testing.B`** benchmarks for hot paths; commit baseline numbers in ADRs when optimizing alloc-heavy code.

### Integration tests

Use **`httptest.Server`** or Docker-based dependencies in CI for integration suites; tag tests with `//go:build integration` so default `go test` stays fast.

## `net/http` Patterns

- **`http.Server`** with sensible `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`, `IdleTimeout`.
- **`http.HandlerFunc`** or small structs implementing `ServeHTTP` for composition.
- Use **`middleware`** chains wrapping `http.Handler`:

```go
func withLogging(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start))
    })
}
```

### `http.Server` timeouts

```go
srv := &http.Server{
    Addr:              ":8080",
    Handler:           handler,
    ReadHeaderTimeout: 5 * time.Second,
    ReadTimeout:       15 * time.Second,
    WriteTimeout:      15 * time.Second,
    IdleTimeout:       60 * time.Second,
}
```

Without `ReadHeaderTimeout`, slowloris-style attacks can exhaust connections.

## Project Layout (`cmd/`, `internal/`, `pkg/`)

```
repo/
  cmd/
    api/
      main.go           # thin: config, wiring, ListenAndServe
  internal/
    httpapi/            # handlers, routes (not importable by other modules)
    domain/
    storage/
  pkg/                  # optional: reusable libraries if you publish modules
  go.mod
```

**Rule**: `internal/` prevents external imports—use for application code. **`cmd/`** holds one `main` per binary. Shared stable libraries may live under **`pkg/`** only when they are truly reusable.

## Interfaces

Interfaces are **satisfied implicitly**. Define small interfaces at the point of use (consumer side), not large “god” interfaces in one file.

```go
type UserReader interface {
    Get(ctx context.Context, id string) (*User, error)
}
```

Mock implementations live in `_test.go` files or `testdata` packages.

### Accept interfaces, return structs

Construct concrete types in constructors; accept interfaces in function parameters. This keeps mocks small and avoids over-abstraction at producers.

## Tooling

| Command | Purpose |
|---------|---------|
| `go test ./...` | Run all tests in module |
| `go test -race ./...` | Data race detector (CI) |
| `go vet ./...` | Static analysis (shadowing, printf, etc.) |
| `golangci-lint run` | Aggregated linters (configure `.golangci.yml`) |
| `go mod tidy` | Prune unused deps; run before merge |

Pin **Go version** in `go.mod` and use the same version in CI images.

### Modules and vendoring

Run **`go mod verify`** in CI when using the module proxy. Vendoring (`go mod vendor`) is optional but helps air-gapped or reproducible Agentic builds—document the policy per repo.

## Documentation and APIs

Document exported symbols with **conventional Go doc comments**; run **`pkgsite`** or `go doc` in CI link checks. For public HTTP APIs, maintain **OpenAPI** (generated or hand-written) alongside handlers so Agentic SDLC consumers stay in sync.

## Performance profiling

Use **`pprof`** endpoints guarded by authentication in staging, or CPU/mem profiles from `runtime/pprof` in batch jobs. Establish baseline alloc profiles before optimizing hot loops—measure first.

## Security

- Use **`crypto/rand`** for tokens; never **`math/rand`** for secrets.
- Pin TLS min version in **`tls.Config`** for outbound clients.
- Redact secrets in logs; pass **`http.Request`** context into audit records without storing raw bodies.

## Generics (Go 1.18+)

Use **type parameters** for reusable data structures (`Set[T]`, `Result[T]`)—avoid over-abstracting business logic. Prefer concrete types in application code unless duplication proves costly.

## `embed` for static assets

Ship migrations and templates with **`embed.FS`** for single-binary deployments—Agentic SDLC artifacts stay reproducible when the binary contains known static files.

## Agentic SDLC Checklist

- All I/O paths propagate `context.Context`.
- Errors wrapped with `%w` where callers need `Is`/`As`.
- HTTP server timeouts set; no `ListenAndServe` without limits in production.
- Table-driven tests for branching logic; race detector in CI for concurrent code.
- `internal/` boundaries enforced; no accidental cross-module coupling.
