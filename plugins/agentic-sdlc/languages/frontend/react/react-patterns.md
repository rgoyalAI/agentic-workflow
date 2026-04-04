# React Patterns for Agentic SDLC

Modern React favors function components, hooks, and explicit data boundaries. This guide covers hooks, server state, composition, testing, performance, structure, and TypeScript discipline for production frontends in automated SDLC.

## Hooks Patterns

**`useState`** for local UI state; prefer **functional updates** when next state depends on previous.

```tsx
const [count, setCount] = useState(0);
setCount((c) => c + 1);
```

**`useEffect`** for synchronization with external systems (subscriptions, DOM, analytics). Include **all dependencies** in the array; split effects by concern to avoid stale closures.

```tsx
useEffect(() => {
  const sub = events.subscribe(handle);
  return () => sub.unsubscribe();
}, [handle]);
```

**`useCallback`** memoizes function identity for stable child props and hook dependencies.

```tsx
const onSave = useCallback(() => {
  saveDraft(form);
}, [form]);
```

**`useMemo`** for expensive derived values; avoid premature optimization—profile first.

```tsx
const sorted = useMemo(() => items.slice().sort(byDate), [items]);
```

**Custom hooks** (`useAuth`, `useDebounce`) encapsulate reusable stateful logic; name them `use*`.

```tsx
export function useDebouncedValue<T>(value: T, delay: number): T {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setV(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return v;
}
```

## State Management

- **Local state**: `useState` / `useReducer` for component-scoped UI.
- **Shared client state**: **Zustand** (or Context + reducer) for modest global needs—keep stores small and typed.
- **Server state**: **TanStack Query (React Query)** for caching, deduplication, background refresh, and optimistic updates.

```tsx
const queryClient = new QueryClient();

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Router />
    </QueryClientProvider>
  );
}

function useOrders() {
  return useQuery({
    queryKey: ["orders"],
    queryFn: () => api.fetchOrders(),
  });
}
```

Avoid duplicating server data in Redux unless you need time-travel or complex client orchestration.

### Query keys and mutations

Namespace query keys: `["orders", orderId]`. Invalidate related lists after **`useMutation`** success:

```tsx
const qc = useQueryClient();
const m = useMutation({
  mutationFn: api.updateOrder,
  onSuccess: (_, v) => qc.invalidateQueries({ queryKey: ["orders", v.id] }),
});
```

Document stale-time vs gc-time defaults per feature so Agentic SDLC performance tests are comparable across branches.

## Component Composition

**Compound components** share implicit state via context (tabs, accordions).

```tsx
<Tabs>
  <Tabs.List>
    <Tabs.Tab id="a">A</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panel id="a">...</Tabs.Panel>
</Tabs>
```

**Render props** and **children as function** remain valid for inversion of control; prefer composition over prop drilling.

## React Testing Library + Vitest

Test **behavior**, not implementation details: assert accessible roles, labels, and user events.

```tsx
import { render, screen, userEvent } from "@testing-library/react";
import { describe, it, expect } from "vitest";

describe("LoginForm", () => {
  it("submits credentials", async () => {
    const onSubmit = vi.fn();
    render(<LoginForm onSubmit={onSubmit} />);
    await userEvent.type(screen.getByLabelText(/email/i), "a@b.com");
    await userEvent.click(screen.getByRole("button", { name: /sign in/i }));
    expect(onSubmit).toHaveBeenCalled();
  });
});
```

Use **MSW** to mock HTTP at the network layer for integration-style tests.

### Accessibility in tests

Prefer **`getByRole`** with accessible names over test IDs. When you must use **`data-testid`**, centralize constants (`data-testid={TEST_IDS.orderRow}`) to avoid brittle string drift.

## Code Splitting

Use **`React.lazy`** + **`Suspense`** for route-level bundles.

```tsx
const Dashboard = lazy(() => import("./features/dashboard/Dashboard"));

export function Routes() {
  return (
    <Suspense fallback={<PageSpinner />}>
      <Dashboard />
    </Suspense>
  );
}
```

Provide meaningful fallbacks; avoid waterfall by prefetching on navigation intent when needed.

### Route-level data

Pair **`lazy`** imports with **route loaders** (React Router 6.4+) or TanStack Router loaders so data fetching starts before paint where appropriate.

## Error Boundaries

Catch render errors in subtrees with **class** error boundaries or **`react-error-boundary`** library.

```tsx
<ErrorBoundary FallbackComponent={ErrorFallback} onError={logToService}>
  <Feature />
</ErrorBoundary>
```

Never use error boundaries for event-handler errors—handle those locally.

## Feature-Based Folder Structure

```
src/
  app/
    providers.tsx
    routes.tsx
  features/
    orders/
      components/
      hooks/
      services/
      types/
      index.ts
  shared/
    ui/
    lib/
  core/
    api-client.ts
    config.ts
```

Co-locate tests (`*.test.tsx`) next to components or under `__tests__` consistently.

### Barrel files

Use **`index.ts`** barrels sparingly—deep barrels can harm tree-shaking and create circular import issues. Export only stable public surfaces from a feature folder.

## TypeScript Strict Mode

Enable **`"strict": true`** in `tsconfig.json`. Prefer **`unknown`** over **`any`**; narrow with type guards.

```ts
function parse(json: string): unknown {
  return JSON.parse(json);
}

function isUser(x: unknown): x is User {
  return typeof x === "object" && x !== null && "id" in x;
}
```

Use **`satisfies`** for literal-checked object shapes; **`const`** assertions for stable tuple types.

### Branding and API types

When IDs are strings, consider **branded types** (`type UserId = string & { __brand: "UserId" }`) for critical domains to prevent accidental mixing—generate Zod/io-ts schemas from OpenAPI when possible.

## Security and env

Never expose secrets in Vite **`import.meta.env`** client bundles—prefix only public vars with `VITE_`. Validate runtime config with a schema on startup for non-dev builds.

## Styling and design systems

Co-locate **CSS Modules**, **Tailwind**, or **styled-components** consistently—mixing three strategies in one feature increases bundle size and review burden. Prefer design tokens (colors, spacing) from a single source for Agentic SDLC UI diffs that are easy to scan.

## Internationalization

Use **react-i18next** or **FormatJS** with namespaces per feature (`orders.json`). Keep default locale strings in repo; load translations lazily for large languages.

## Forms and validation

Pair **React Hook Form** with **Zod** resolvers for client-side validation that mirrors server rules. Disable submit buttons while **`formState.isSubmitting`** to prevent double posts; surface server field errors next to inputs.

## Performance monitoring

Integrate **Web Vitals** (CLS, LCP, INP) with your analytics pipeline. Track release markers so Agentic SDLC can correlate UI regressions with deploys.

## Agentic SDLC Checklist

- Hooks dependency arrays complete; ESLint `react-hooks/exhaustive-deps` enabled.
- TanStack Query for remote data; keys versioned when API changes.
- RTL tests cover critical user flows; Vitest in CI with coverage thresholds optional.
- Lazy routes for large features; error boundaries on route shells.
- Features own their API types and mappers; `shared` only for truly generic UI.
