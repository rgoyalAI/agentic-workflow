# React / Next.js — Feature-Based Frontend

Organize UI by **feature** (user-facing capability) and keep **shared** design-system pieces separate. **Pages stay thin** — compose features and shared layout, avoid business logic in `page.tsx` when it belongs in hooks or services.

## Layout (Next.js App Router example)

```
src/
├── app/                             # Next.js routes: layout.tsx, page.tsx, loading.tsx, error.tsx
│   ├── (auth)/
│   ├── (dashboard)/
│   └── api/                         # Route handlers if needed
├── features/
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/                # API calls for this feature
│   │   ├── types/
│   │   └── index.ts                 # Barrel export — public API of the feature
│   ├── orders/
│   └── dashboard/
├── shared/
│   ├── components/
│   │   ├── ui/                      # Button, Input, Card — primitive design system
│   │   ├── layout/                  # Shell, Sidebar, PageHeader
│   │   └── feedback/                # Toasts, EmptyState, ErrorBoundary UI
│   ├── hooks/
│   ├── utils/
│   └── types/
├── lib/
│   ├── api/                         # fetch wrapper, React Query clients, base URLs
│   ├── queries/                     # TanStack Query keys + factories (optional grouping)
│   └── stores/                      # Zustand/Jotai if used
└── styles/
    ├── globals.css
    └── tokens.css                   # CSS variables from design tokens
```

## Feature folders

- **`features/<name>/`**: Everything specific to that capability — **components** only used here, **hooks** (`useOrders`), **services** (REST calls), **types**.
- **`index.ts`**: Re-export what other parts of the app may import — hides internals (`internal` pattern for TS paths optional).

## Shared design system

- **`shared/components/ui/`**: Atoms/molecules aligned with **design tokens** — no feature-specific copy or routes.
- **`shared/components/layout/`**: Application chrome — nav regions, responsive shell.

## Lib layer

- **`lib/api`**: Centralize base URL, auth header injection, error normalization.
- **`lib/queries`**: Query key conventions and shared fetchers for cache consistency.

## Styles

- **`styles/globals.css`**: Reset, base typography, imports.
- **`styles/tokens.css`**: `--color-*`, `--space-*`, etc. — single source for Tailwind `@theme` or manual usage.

## Key rules

1. **Feature folders with barrel exports** — import from `@/features/orders` not deep paths when stable.
2. **`shared/`** for reusable UI — do not import `features/foo` from `shared/` (dependency inversion: pass render props or slots).
3. **Pages are thin** — data fetching hooks + composition; complex logic in `features/*/hooks` or `services`.
4. **Colocate tests** — `features/orders/components/OrderList.test.tsx` or `__tests__` per feature.

## Anti-patterns

- `shared/components` importing feature code — creates cycles and blurs boundaries.
- Copy-pasting API URLs in every component — use `lib/api`.
