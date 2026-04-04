# UI Generation Specification (Plan Sections 7.7.1–7.7.10)

This document defines **mandatory** behaviors and structures for AI- or team-generated frontends. It applies to React/Next.js, Angular, Vue, or similar stacks unless a project ADR explicitly narrows the stack.

---

## 7.7.1 Design System Foundation (Design Tokens)

Design tokens are the **single source of truth** for visual properties. No hard-coded hex colors or magic numbers in components except documented exceptions (e.g. third-party chart defaults wrapped in adapters).

### Required token categories

| Category | Purpose | Examples |
|----------|---------|----------|
| **Color** | Brand, semantic states, surfaces | `color.primary`, `color.danger`, `color.surface.canvas` |
| **Spacing** | Padding, margin, gap, stack rhythm | `space.1` … `space.8` (4px or 8px base scale) |
| **Typography** | Font family, size, weight, line height | `font.body`, `font.heading.lg`, `font.mono` |
| **Border** | Width, radius, style | `radius.sm`, `radius.md`, `border.width.hairline` |
| **Shadow** | Elevation levels | `shadow.sm`, `shadow.overlay` |
| **Motion** | Duration, easing | `duration.fast`, `easing.standard` |
| **Z-index** | Layering contract | `z.dropdown`, `z.modal`, `z.toast` |
| **Breakpoint** | Responsive layout | `breakpoint.sm`, `breakpoint.md`, `breakpoint.lg` |

**Rules**

- Tokens are **named by role**, not by raw value (`primary` not `#3366ff` in API names).
- **Semantic tokens** (e.g. `color.text.primary`) map to **palette tokens** for theming and dark mode.
- Implementation: **CSS custom properties** on `:root` and `[data-theme="dark"]`, or framework equivalents — see `design-tokens.md`.

### Token governance

| Activity | Owner | Artifact |
|----------|-------|----------|
| Add new token | Design + FE lead | PR + Storybook/chromatic proof |
| Deprecate token | Design system | Changelog + codemod or search ticket |
| Dark mode parity | FE | Contrast report for both themes |

### Anti-patterns

- Duplicating token values in **three** places (Figma export, CSS, Tailwind) without automation — pick a **single build step** that generates consumers.
- Using **raw** `z-index: 9999` — use named layers from the token table.

---

## 7.7.2 Component Architecture (Atomic Design)

Structure reusable UI in **Atomic Design** layers. Generated code must declare which layer each file belongs to (folder or file header comment).

| Layer | Definition | Examples |
|-------|------------|----------|
| **Atoms** | Smallest building blocks; no business meaning | Button, Input, Icon, Badge |
| **Molecules** | Simple groups of atoms | FormField, SearchBar, Card header |
| **Organisms** | Complex sections with internal state or composition | DataTable, Modal, App header |
| **Templates** | Page-level layout without real data | Dashboard shell, auth layout |
| **Pages** | Templates + real data and routing | Wire features here; keep thin |

**Rules**

- Atoms **do not** import organisms or feature modules.
- Organisms may compose molecules and atoms; **features** may compose organisms + data hooks.
- **Barrel files** (`index.ts`) export only the **public** surface of a folder.

### Composition rules

| From → To | Allowed |
|-----------|---------|
| Atom → Organism | No |
| Molecule → Atom | Yes |
| Feature → Shared UI | Yes |
| Shared UI → Feature | No (inversion via props/slots) |

### State ownership

- **UI state** (open/closed, tab index) lives in the **lowest** component that needs it.
- **Server/cache state** (lists, user session) lives in **data layer** (TanStack Query, NgRx, services) — not duplicated in atom props.

---

## 7.7.3 Styling Architecture

**Preference order** (highest first):

1. **Tailwind CSS** (with design tokens mapped in `tailwind.config` / `@theme`) — fastest consistency for generated UIs.
2. **CSS Modules** — component-scoped class names, no runtime CSS-in-JS cost.
3. **SCSS + BEM** — legacy-friendly; require strict BEM naming and token variables.

**Rules**

- **No** inline styles for recurring patterns — extract to tokens or utility classes.
- **Global** styles limited to resets, typography base, and token definitions.
- **Theme switching**: class or data-attribute on `html`/`body`; avoid flash of wrong theme (SSR: inline critical script if needed).

### Tailwind integration (when used)

- Map tokens to **`@theme`** or `theme.extend` once; forbid **arbitrary values** (`text-[13px]`) except in prototypes behind `// TODO tokenize`.
- Use **`container`** or **max-width utilities** aligned to breakpoints table — not one-off `max-w-[1234px]`.

### CSS Modules / SCSS

- **Class names** reflect component and element (`Button__label`) when BEM; **no** deep selectors coupling to third-party DOM.
- **Variables**: SCSS `$token-*` imported from a single **`_tokens.scss`** generated or hand-maintained to match `design-tokens.md`.

---

## 7.7.4 Responsive Design (Mobile-First)

### Breakpoints (default contract)

| Name | Min width | Typical use |
|------|-----------|-------------|
| `xs` | 0 | Base — mobile portrait |
| `sm` | 640px | Large phones, small tablets |
| `md` | 768px | Tablets |
| `lg` | 1024px | Laptops |
| `xl` | 1280px | Desktops |
| `2xl` | 1536px | Wide monitors |

**Mobile-first rule**: Base CSS applies to smallest viewport; **`min-width`** media queries add complexity.

### Layout patterns

| Pattern | Behavior |
|---------|----------|
| **Stack** | Vertical flex/grid; gap from token scale |
| **Sidebar + content** | Collapsible nav below `md`; persistent sidebar `lg+` |
| **Split view** | List/detail: single column on mobile; split `md+` |
| **Fluid container** | Max-width + horizontal padding tokens |

### Content density

| Viewport | Guidance |
|----------|----------|
| Mobile | Single column; avoid horizontal scroll except intentional carousels (with focus management) |
| Tablet | Optional two-column for dashboards; touch-first spacing |
| Desktop | Use **max readable line length** (~65–75ch) for long prose |

### Images and media

- **`srcset`** / `sizes` for responsive images; **art direction** with `<picture>` when crop differs by breakpoint.
- **Video**: captions required if audio conveys information; **poster** image sized to layout.

---

## 7.7.5 Navigation Patterns

### Primary navigation

- **Location**: Header or left rail on desktop; **drawer/bottom nav** on mobile for apps with ≤5 primary items.
- **State**: Current route highlighted; **keyboard** and **focus** order match visual order.
- **Deep links**: All navigable screens have stable URLs (Next.js/App Router or Angular router).

### Secondary navigation

- Tabs, sub-menus, or in-page anchors for subsection — must not trap focus (see accessibility).

### Route structure

- **Hierarchical paths**: `/orders`, `/orders/[id]`, `/settings/profile`.
- **Auth gates**: Redirect unauthenticated users to login with **return URL** preserved.

### Mobile navigation

- **Hamburger → drawer** or **bottom tab bar**; large touch targets (min 44×44 CSS px).
- Avoid hover-only menus — provide tap/click equivalents.

### Breadcrumbs and wayfinding

- Show **hierarchy** for deep IA; last crumb is **current page** (not a link).
- On mobile, consider **truncation** with ellipsis + full trail in a disclosure.

### URL and state

- **Bookmarkable** filters/sorts: reflect in query params when product needs shareable views (`?sort=date&dir=desc`).
- Avoid **only** storing critical state in memory — restore from URL on refresh where applicable.

---

## 7.7.6 Form Design and Validation

### Progressive disclosure

- Show **required fields first**; advanced options behind disclosure (accordion, “More options”).
- **Multi-step forms**: Clear step indicator, persist draft where product allows (localStorage or API).

### Inline validation

- Validate on **blur** for format fields; on **submit** for completeness.
- **Error text** tied to inputs with `aria-describedby`; errors summarized at top for long forms (`role="alert"`).

### Stack conventions

- **React**: **React Hook Form** + **Zod** (`@hookform/resolvers`) for schema validation.
- **Angular**: **Reactive Forms** + **Validators**; optional Zod via interop if team standardizes.

### UX

- **Disable submit** while invalid or pending; show loading state on button.
- **Password managers**: Correct `autocomplete` attributes; no blocking `readonly` hacks for accessibility.

### Internationalization (i18n)

- **No** string concatenation for sentences — use ICU **message format** with placeholders.
- **Layout**: Allow **text expansion** (German, Finnish); avoid fixed-width labels.
- **Dates/numbers**: `Intl` APIs or libraries; **timezone** explicit for scheduling UIs.

### File upload

- **Accept** attribute aligned with server validation; show **max size** and **formats** before upload.
- **Progress** and **error** per file; virus scan messaging if backend async.

---

## 7.7.7 Data Display

### DataTable requirements

- **Sortable** columns where data supports it; **keyboard** operable headers.
- **Pagination** or **virtualization** for large sets — never render 10k rows in DOM.
- **Empty**, **loading**, and **error** states required.
- **Row actions** in consistent column; destructive actions confirm.

### Virtualized lists

- Use **windowing** (`react-window`, CDK Virtual Scroll) for lists >100 items when profiling shows jank.

### Dashboards / charts

- **Color** must not be sole differentiator — patterns/labels for WCAG.
- **Responsive** chart containers; debounce resize.
- Provide **data table alternative** or export where compliance requires.

### Real-time updates

- **Websockets/SSE**: Show **connection status**; reconcile optimistic UI with server truth; idempotent retries.
- **Polling**: Backoff and **pause** when tab hidden (`document.visibilityState`).

---

## 7.7.8 Accessibility (WCAG 2.1 Level AA)

See `accessibility-checklist.md` for the code-level checklist. The following **requirements table** summarizes Section 7.7.8 for generation and review.

| Area | Requirement | Implementation detail |
|------|-------------|------------------------|
| **Contrast** | 4.5:1 normal text; 3:1 large text and UI graphics | Token-based colors checked in CI |
| **Zoom** | Reflow to 320 CSS px width without loss | No fixed-width modals that clip content |
| **Keyboard** | All interactive controls operable | Tab order = reading order; no positive `tabindex` abuse |
| **Focus** | Visible focus ring on all themes | Custom ring uses token stroke + offset |
| **Motion** | Respect `prefers-reduced-motion` | Disable non-essential animation |
| **Semantics** | Correct landmarks (`main`, `nav`, `header`) | One `main` per page |
| **Forms** | Labels, descriptions, error association | `aria-describedby`, `aria-invalid` |
| **Live regions** | Toasts/status use `aria-live` appropriately | `polite` default; `assertive` for critical errors |
| **Tables** | `<th>` scope or `headers` for complex grids | Caption or `aria-label` for purpose |
| **Modals** | Focus trap, Escape, restore focus | `aria-modal="true"` |

**POUR summary**

- **Perceivable**: contrast, text resize, non-color cues.
- **Operable**: keyboard, focus visible, no seizure triggers.
- **Understandable**: labels, errors, language (`lang` attribute).
- **Robust**: valid roles, names, states for assistive technology.

---

## 7.7.9 Frontend Performance

### Core Web Vitals (targets)

| Metric | Target (good) |
|--------|-----------------|
| **LCP** | ≤ 2.5 s (p75) |
| **INP** | ≤ 200 ms (p75) |
| **CLS** | ≤ 0.1 (p75) |

### Code splitting rules

- **Route-level** lazy loading for feature areas.
- **Heavy** deps (charts, editors) loaded dynamically (`import()`).
- **Images**: modern formats, explicit `width`/`height`, `loading="lazy"` below fold.
- **Fonts**: `font-display: swap`, subset when possible.

### Runtime

- Avoid unnecessary **re-renders** (memo, selectors, signals).
- **Lists**: stable `key`; avoid inline object/array props that break memoization.

### Bundles and dependencies

- **Audit** bundle size on PR for large additions (`webpack-bundle-analyzer`, **source-map-explorer**).
- Prefer **tree-shakeable** libraries; avoid importing entire icon packs — **per-icon** imports.

### Caching

- **HTTP**: `Cache-Control` for static assets with **fingerprinted** filenames.
- **Client**: Stale-while-revalidate patterns for API data where UX allows (document staleness).

### Networking

- **Debounce** search inputs; **cancel** in-flight requests on unmount or param change (`AbortController`).

---

## 7.7.10 Reusable Component Checklist (10 items)

Before merging a new shared component:

1. **Tokens only** — no raw colors/spacing outside the token system.
2. **Props typed** — TypeScript interfaces or JSDoc for JS projects.
3. **Forwarded ref** where DOM focus or measurement is needed.
4. **Accessible name** — visible label or `aria-label` when no visible text.
5. **Focus style** visible and not removed without replacement.
6. **Keyboard** — operable without mouse for interactive controls.
7. **States** — loading, disabled, error, empty documented and styled.
8. **Responsive** — verified at smallest and largest breakpoints.
9. **Dark mode** — tested if product supports themes.
10. **Tests** — unit test for behavior; axe test in CI for shared primitives.

### Documentation for shared components

- **Storybook** (or equivalent): controls for **variants**, **states**, and **a11y** panel green.
- **Props table** generated from TypeScript where possible — single source of truth.

---

## Cross-references

- Token details: `design-tokens.md`
- A11y tests: `accessibility-checklist.md`
- Component inventory: `component-catalog.md`
- REST/API contracts consumed by the UI: `standards/api/rest-standards.md`

## Generation workflow (for agents)

1. Read **design tokens** and **component catalog** before emitting JSX/templates.
2. Place new UI in correct **atomic** folder and **feature** boundary per `react.md` / `angular.md` standards.
3. Run **mental checklist**: responsive base styles, then `min-width` enhancements.
4. Attach **a11y** and **performance** notes to the PR summary when tooling cannot run in session.

