# Angular Patterns for Agentic SDLC

Angular 17+ emphasizes **standalone components**, typed templates, and signals for fine-grained reactivity. This guide covers architecture, RxJS, forms, routing, testing, and folder layout for enterprise SPAs in automated SDLC.

## Standalone Components (Angular 17+)

Prefer **`standalone: true`** components with explicit **`imports`** instead of NgModules for new work.

```typescript
@Component({
  standalone: true,
  selector: "app-order-summary",
  imports: [CommonModule, RouterLink, MatCardModule],
  templateUrl: "./order-summary.component.html",
})
export class OrderSummaryComponent {
  readonly order = input.required<Order>();
}
```

Bootstrap with **`bootstrapApplication`** and **`provideRouter`** / **`provideHttpClient`** in `main.ts`.

## Modules vs Standalone Migration

Legacy **`NgModule`**-based apps can migrate incrementally: convert leaf features to standalone, then delete redundant modules. Use **`RouterModule.forChild`** equivalents via **`routes`** in standalone routing.

```typescript
export const routes: Routes = [
  {
    path: "orders",
    loadChildren: () => import("./features/orders/order.routes").then((m) => m.ORDER_ROUTES),
  },
];
```

Keep **`SharedModule`** only while bridging; goal is feature-local imports.

### Route providers

Use **`providers: [OrderService]`** on a route when a service should be scoped to a feature subtree instead of global singletons.

## Services and `providedIn`

Register singletons with **`providedIn: 'root'`** unless a service must be scoped to a route/component.

```typescript
@Injectable({ providedIn: "root" })
export class OrderService {
  private readonly http = inject(HttpClient);

  list(): Observable<Order[]> {
    return this.http.get<Order[]>("/api/orders");
  }
}
```

Use **`inject()`** in constructors or field initializers for concise DI in standalone components.

## RxJS Patterns

- **`switchMap`** for canceling in-flight requests when a new outer emission arrives (search-as-you-type).
- **`catchError`** to map HTTP failures to fallback observables or rethrow with context.
- **`takeUntil(destroy$)`** for unsubscribing in class-based components; **`takeUntilDestroyed`** with **`inject(DestroyRef)`** in modern Angular.

```typescript
readonly results$ = this.search$.pipe(
  debounceTime(300),
  distinctUntilChanged(),
  switchMap((q) =>
    this.api.search(q).pipe(
      catchError(() => of([] as Result[])),
    ),
  ),
);
```

Prefer **async pipe** in templates to avoid manual subscribe in components.

### HTTP interceptors

Centralize **`HttpInterceptorFn`** (functional interceptors) for auth headers, retries with backoff, and correlation IDs—register in **`provideHttpClient(withInterceptors([...]))`**.

## Angular Signals

Use **signals** for local UI state and **computed** for derived values; **`effect`** for side effects (logging, syncing to DOM)—avoid heavy work in effects.

```typescript
readonly count = signal(0);
readonly doubled = computed(() => this.count() * 2);

increment(): void {
  this.count.update((c) => c + 1);
}
```

Interoperate with RxJS via **`toSignal`** / **`toObservable`** when bridging existing streams.

## Reactive Forms and Validators

**`FormBuilder`** with **`FormGroup`** / **`FormArray`**; extract **custom validators** as pure functions.

```typescript
this.form = this.fb.group({
  email: ["", [Validators.required, Validators.email]],
  quantity: [1, [Validators.required, Validators.min(1)]],
});

function skuValidator(control: AbstractControl): ValidationErrors | null {
  const v = control.value as string;
  return v && !/^[A-Z0-9-]+$/.test(v) ? { sku: true } : null;
}
```

Use **`valueChanges`** with **`debounceTime`** for async validation that hits the server.

### Template-driven vs reactive

Prefer **reactive forms** for complex validation and unit testing; use template-driven forms only for simple prototypes—mixed strategies confuse Agentic SDLC test generation.

## Lazy-Loaded Routes

Split bundles with **`loadComponent`** or **`loadChildren`**.

```typescript
{
  path: "reports",
  loadComponent: () =>
    import("./features/reports/report-shell.component").then((m) => m.ReportShellComponent),
}
```

Provide route data resolvers or **`fetch`** guards for data prerequisites.

### Preloading

Enable **custom preloading strategies** for high-priority feature bundles after initial shell load—balance TTI with network usage.

## Jasmine/Karma + Testing Utilities

Use **`TestBed.configureTestingModule`** with **standalone** imports mirroring the component.

```typescript
describe("OrderSummaryComponent", () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [OrderSummaryComponent, NoopAnimationsModule],
    }).compileComponents();
  });

  it("renders total", () => {
    const fixture = TestBed.createComponent(OrderSummaryComponent);
    fixture.componentRef.setInput("order", { id: "1", total: 42 });
    fixture.detectChanges();
    expect(fixture.nativeElement.textContent).toContain("42");
  });
});
```

Prefer **`HarnessLoader`** for Material components when applicable.

### Spectator (optional)

**@ngneat/spectator** reduces `TestBed` boilerplate; adopt consistently or stick to plain TestBed—mixed styles complicate Agentic templates.

## Folder Structure: `core/`, `shared/`, `features/`

```
src/app/
  core/
    interceptors/
    guards/
    services/
  shared/
    ui/
    pipes/
  features/
    orders/
      data/
      pages/
      order.routes.ts
  app.config.ts
  app.routes.ts
```

**`core`**: singleton services, HTTP interceptors, auth guards—import once from `App`. **`shared`**: dumb components and pipes. **`features`**: routed slices with local state and data services.

## Change detection and performance

Prefer **`ChangeDetectionStrategy.OnPush`** for leaf components; ensure inputs are immutable or signal-based updates so OnPush receives new references. Profile with Angular DevTools before micro-optimizing.

## i18n and a11y

Use **`@angular/localize`** or **ngx-translate** with stable message IDs for Agentic SDLC string freeze. Pair with **CDK a11y** utilities (`FocusTrap`, `LiveAnnouncer`) for dialogs.

## State stores vs signals

For cross-route client state, evaluate **NgRx** or **Elf** only when complexity warrants time-travel debugging; otherwise prefer **signals** + small services. Document the decision in `ARCHITECTURE.md` when Agentic agents need to choose patterns.

## SSR and hydration (optional)

If using **Angular Universal**, guard browser-only APIs with **`isPlatformBrowser`** checks; keep server bundles free of direct `window` access. Hydration mismatches should be caught by integration tests against rendered HTML.

## Build and lint

Enable **strict templates**, **ESLint** with **@angular-eslint**, and **Prettier** in CI. Fail builds on **budgets** (`angular.json` bundle limits) when features regress performance.

## Animations

Use **`@angular/animations`** with **`NoopAnimationsModule`** in tests to keep unit runs fast. Prefer CSS transitions for simple effects; reserve Angular animations for complex coordinated sequences.

## Content projection

Leverage **`ng-content`** with **`select`** attributes for flexible layout components (cards, toolbars). Document slot contracts so Agentic agents do not break parent/child expectations when refactoring templates.

## Dependency injection tokens

Use **InjectionToken** for configuration objects (feature flags, API base URLs) instead of magic strings—keeps `provide*` functions type-safe and discoverable.

## Route guards

Implement **functional guards** (`CanActivateFn`) returning `Observable<boolean> | Promise<boolean> | boolean` for auth and feature toggles. Compose guards on routes instead of duplicating checks inside components.

## Template typing

Enable **strictTemplates** and fix `$event` typing in handlers—use component methods with explicit parameter types rather than inline casts in templates.

## Agentic SDLC Checklist

- New components standalone; routing uses lazy loading for large features.
- RxJS pipelines avoid memory leaks (`takeUntilDestroyed` / async pipe).
- Signals used for synchronous UI state; RxJS for async streams until full signal-resource APIs cover your case.
- Reactive forms validated at boundary; custom validators unit-tested.
- Tests use `TestBed` + minimal imports; CI runs `ng test --no-watch --browsers=ChromeHeadless`.
