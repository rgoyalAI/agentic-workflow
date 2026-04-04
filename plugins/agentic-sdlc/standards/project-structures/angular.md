# Angular — Standalone, Core, Shared, Features

Angular apps scale with **standalone components**, a thin **`core/`** module for singletons, **`shared/`** for dumb UI, and **lazy-loaded `features/`** per area.

## Layout

```
src/
├── app/
│   ├── app.component.ts
│   ├── app.config.ts                # provideRouter, provideHttpClient, interceptors
│   ├── app.routes.ts                # Top-level routes with loadChildren → features
├── core/
│   ├── interceptors/                # Auth, error, correlation ID
│   ├── guards/                      # auth.guard, role.guard
│   ├── services/                    # Singletons: SessionService, Logger facade
│   └── layout/                    # App shell if not in shared (optional)
├── shared/
│   ├── components/
│   ├── directives/
│   └── pipes/
├── features/
│   ├── auth/
│   │   ├── pages/
│   │   ├── components/
│   │   ├── data-access/             # NgRx feature store or injectable API services
│   │   ├── state/                   # reducers, effects if used
│   │   └── auth.routes.ts
│   ├── orders/
│   └── dashboard/
└── environments/
    ├── environment.ts
    └── environment.prod.ts
```

## Standalone components

- Prefer **`standalone: true`** components and **direct imports** in each component — reduces NgModule boilerplate.
- **`app.config.ts`**: `provideRouter(routes)`, `provideHttpClient(withInterceptors([...]))`, other root providers.

## Core

- **`core/`** should be imported **once** in `app.config` / root — services are **singletons** (providedIn: 'root' or explicit).
- **Interceptors**, **guards**, and **session-wide services** live here — not duplicated per feature.

## Shared

- **Presentational** components, pipes, directives with **no** feature-specific routing or store dependencies.
- No imports from `features/*` inside `shared/`.

## Features

- **`features/auth/`**: **pages** (smart containers), **components** (scoped dumb UI), **data-access** (HTTP + caching), **state** (signals/store), **routes** for lazy loading.
- **`loadChildren`** in `app.routes.ts`: `() => import('./features/auth/auth.routes').then(m => m.AUTH_ROUTES)`.

## Environments

- **`environment.ts` / `environment.prod.ts`**: API base URL, feature flags — replace at build via `fileReplacements` in `angular.json`.

## Key rules

1. **Standalone components** for new code; migrate legacy modules incrementally.
2. **`core/`** — singletons and HTTP/auth cross-cutting concerns only.
3. **Features lazy-loaded** — faster initial bundle; each feature owns its routes and state.
4. **Smart vs dumb** — pages orchestrate; shared components receive `@Input()` / outputs.

## Testing

- **Jest** or **Karma** per team standard — colocate `*.spec.ts` next to sources.
- Use **`HttpTestingController`** for data-access tests; shallow test standalone components with `TestBed`.

## Anti-patterns

- Importing `SharedModule` everywhere with unused exports — prefer explicit standalone imports.
- Business logic in templates — use component class methods or pipes.
