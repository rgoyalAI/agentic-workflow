# Gin Patterns for Agentic SDLC

[Gin](https://github.com/gin-gonic/gin) is a fast HTTP web framework for Go. Use router groups, middleware chains, binding validation, and `httptest` for reliable APIs in automated pipelines.

## Router Groups and Middleware

Group routes by **version** and **domain**. Apply middleware in order: recovery, logging, auth, then handlers.

```go
r := gin.New()
r.Use(gin.Recovery())
r.Use(requestIDMiddleware())

v1 := r.Group("/api/v1")
{
    v1.GET("/health", healthHandler)
    auth := v1.Group("")
    auth.Use(jwtAuthMiddleware())
    {
        auth.GET("/me", meHandler)
    }
}
```

**Middleware** signature: `func(c *gin.Context)`. Call `c.Next()` to continue; `c.Abort()` to stop the chain.

```go
func jwtAuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
            return
        }
        c.Next()
    }
}
```

### Request-scoped values

Use **`c.Set` / `c.Get`** for user ID and request ID after auth middleware. Define typed keys (private `type ctxKey int`) in a shared package to avoid string collisions.

## Binding and Validation

Use **`ShouldBindJSON`** (non-strict) or **`BindJSON`** (writes 400 on failure) with struct tags from **`validator/v10`** (via `binding` tags).

```go
type createItem struct {
    Name  string `json:"name" binding:"required,min=1,max=200"`
    Count int    `json:"count" binding:"required,min=1"`
}

func createItemHandler(c *gin.Context) {
    var req createItem
    if err := c.ShouldBindJSON(&req); err != nil {
        c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    // ...
}
```

For custom validation, register validators on the engine’s binding validator or validate manually after bind.

### Query and URI parameters

Use **`ShouldBindQuery`** for `?page=` style params and **`uri:"id"`** tags for path segments. Combine with the same struct tags for consistent validation across GET and POST handlers.

## Testing Mode

Set **`gin.SetMode(gin.TestMode)`** in tests to suppress debug output and reduce noise.

```go
func TestMain(m *testing.M) {
    gin.SetMode(gin.TestMode)
    os.Exit(m.Run())
}
```

## `httptest` Integration

Use **`httptest.NewRecorder`** and Gin’s **`ServeHTTP`** to test handlers without a network port.

```go
func TestHealth(t *testing.T) {
    r := gin.New()
    r.GET("/health", func(c *gin.Context) { c.Status(http.StatusOK) })

    req := httptest.NewRequest(http.MethodGet, "/health", nil)
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)

    if w.Code != http.StatusOK {
        t.Fatalf("status %d", w.Code)
    }
}
```

For full JSON assertions, compare response bodies against golden files or `encoding/json` unmarshaling.

## Error Handling Middleware

Centralize **error mapping**: handlers return domain errors or set `c.Error(err)`; middleware translates to JSON.

```go
func errorMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()
        if len(c.Errors) > 0 {
            err := c.Errors.Last().Err
            switch {
            case errors.Is(err, domain.ErrNotFound):
                c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
            default:
                c.JSON(http.StatusInternalServerError, gin.H{"error": "internal"})
            }
        }
    }
}
```

Avoid logging sensitive request fields; redact tokens and PII.

## CORS and Auth Patterns

- **CORS**: Use `github.com/gin-contrib/cors` with explicit origins in production—never `*` with credentials.
- **Auth**: Extract Bearer/JWT in middleware; set `c.Set("userID", id)` for downstream handlers; document keys in one place.

```go
config := cors.Config{
    AllowOrigins:     []string{"https://app.example.com"},
    AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE"},
    AllowHeaders:     []string{"Authorization", "Content-Type"},
    AllowCredentials: true,
}
r.Use(cors.New(config))
```

## Graceful shutdown

Combine **`http.Server`** with **`signal.Notify`** for SIGINT/SIGTERM so Kubernetes rollouts drain in-flight requests before exit. Gin’s `Run` is convenient for dev; production binaries should use `srv.ListenAndServe` + `Shutdown(ctx)` with a timeout.

## Observability

Emit **Prometheus** metrics via `promhttp` or OpenTelemetry Gin middleware. Log one line per request with status, latency, and `request_id`—avoid logging full bodies.

## Agentic SDLC Checklist

- Route groups versioned (`/api/v1`); middleware order documented.
- All JSON inputs validated via binding tags or explicit validators.
- `gin.TestMode` in tests; `httptest` covers success and 4xx paths.
- Error middleware returns stable JSON shapes; correlation ID in logs.
- CORS and JWT settings aligned with security review for new public routes.
