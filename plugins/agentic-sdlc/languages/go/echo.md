# Echo Patterns for Agentic SDLC

[Echo](https://echo.labstack.com/) is a minimalist Go web framework with strong typing and middleware. Use groups, `echo.Context`, validators, and built-in testing utilities for maintainable HTTP services.

## Routing and Groups

Create **`echo.New()`**, configure **`Echo#Pre`** for global pre-middleware (rewrite, trim slash), then register routes on **groups**.

```go
e := echo.New()
e.Pre(middleware.RemoveTrailingSlash())

api := e.Group("/api/v1")
api.GET("/health", health)

secured := api.Group("")
secured.Use(jwtMiddleware)
secured.GET("/profile", profile)
```

**Route naming**: Use consistent REST nouns; return `echo.NewHTTPError` for domain failures with proper codes.

## Context and Validator

**`echo.Context`** wraps `http.ResponseWriter` and `*http.Request`. Prefer **`c.Request().Context()`** when calling downstream services that need cancellation.

Echo v4 integrates **validator** via `github.com/go-playground/validator/v10`:

```go
type createReq struct {
    Title string `json:"title" validate:"required,min=3"`
}

e.Validator = &CustomValidator{v: validator.New()}

func create(c echo.Context) error {
    var req createReq
    if err := c.Bind(&req); err != nil {
        return echo.NewHTTPError(http.StatusBadRequest, err.Error())
    }
    if err := c.Validate(&req); err != nil {
        return echo.NewHTTPError(http.StatusBadRequest, err.Error())
    }
    return c.JSON(http.StatusCreated, req)
}
```

Implement `echo.Validator` interface with a small wrapper around `validator.Validate`.

```go
type CustomValidator struct{ v *validator.Validate }

func (cv *CustomValidator) Validate(i interface{}) error {
    if err := cv.v.Struct(i); err != nil {
        return echo.NewHTTPError(http.StatusBadRequest, err.Error())
    }
    return nil
}
```

## Bind + Validate Pattern

1. **`Bind`** (JSON, query, path) into a struct.
2. **Validate** with struct tags.
3. Call **service** layer with `Context` from request.

```go
func (h *Handler) Get(c echo.Context) error {
    id := c.Param("id")
    if id == "" {
        return echo.NewHTTPError(http.StatusBadRequest, "id required")
    }
    item, err := h.svc.Get(c.Request().Context(), id)
    if errors.Is(err, service.ErrNotFound) {
        return echo.NewHTTPError(http.StatusNotFound, "not found")
    }
    if err != nil {
        return err
    }
    return c.JSON(http.StatusOK, item)
}
```

Keep handlers thin; business rules live in `service` packages.

## Echo Testing Utilities

Use **`httptest`** with **`rec := httptest.NewRecorder()`** and **`e.ServeHTTP(rec, req)`**, or **`testify`** for assertions.

```go
func TestHealth(t *testing.T) {
    e := echo.New()
    e.GET("/health", func(c echo.Context) error {
        return c.NoContent(http.StatusOK)
    })

    req := httptest.NewRequest(http.MethodGet, "/health", nil)
    rec := httptest.NewRecorder()
    e.ServeHTTP(rec, req)

    if rec.Code != http.StatusOK {
        t.Fatalf("got %d", rec.Code)
    }
}
```

For integration tests, start the server on a random port with `e.Start` in a goroutine and use real HTTP client—only when necessary.

### Echo’s `e.NewContext`

For table-driven handler tests, you may construct **`echo.NewContext(req, rec)`** when testing functions that take `echo.Context` without building the full engine—useful for pure handler units.

## Error Handler Customization

Set **`e.HTTPErrorHandler`** to unify JSON error bodies and logging.

```go
e.HTTPErrorHandler = func(err error, c echo.Context) {
    code := http.StatusInternalServerError
    if he, ok := err.(*echo.HTTPError); ok {
        code = he.Code
    }
    c.Logger().Error(err)
    _ = c.JSON(code, map[string]string{"message": http.StatusText(code)})
}
```

Map known domain errors before falling back to generic 500; never return stack traces to clients.

## Middleware: Logger, Recover, CORS, JWT

```go
e.Use(middleware.Logger())
e.Use(middleware.Recover())
e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
    AllowOrigins: []string{"https://app.example.com"},
    AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodDelete},
}))
```

**JWT**: Use `github.com/labstack/echo-jwt/v4` with `echojwt.Config` and claims; validate issuer/audience in production.

```go
g := e.Group("/api")
g.Use(echojwt.WithConfig(echojwt.Config{
    SigningKey: []byte(os.Getenv("JWT_SECRET")),
}))
```

Rotate secrets via env/KMS; never log raw tokens.

## Server tuning

Set **`e.Server.ReadTimeout`**, **`WriteTimeout`**, and **`IdleTimeout`** when calling `e.StartServer`. Tune **`e.HideBanner`** in production logs and **`e.Debug`** only in development.

## Agentic SDLC Checklist

- Groups mirror API boundaries; JWT applied only where needed.
- `Bind` + `Validate` on all request bodies; path/query validated explicitly.
- Custom `HTTPErrorHandler` for consistent JSON and status codes.
- Logger/recover middleware enabled; CORS restricted by environment.
- Tests use `httptest` for handlers; critical paths covered for 2xx/4xx/5xx.
