# Design Tokens — Naming, Categories, and Implementation

## Naming conventions

- **Pattern**: `{category}.{semantic-role}[.{variant}]`
  - Examples: `color.text.primary`, `space.stack.md`, `font.size.body`.
- **Use American English** in token names (`color.gray` not `colour`).
- **Avoid** framework-specific prefixes in the canonical name — map to Tailwind/Angular at build time.
- **Scale indices**: Prefer **named steps** (`sm`, `md`, `lg`) over numbers in public API unless a numeric scale is documented (e.g. `space.4` = 16px).

## Categories table

| Category | Description | Example tokens |
|----------|-------------|----------------|
| **colors** | Brand palette + semantic | `color.brand.500`, `color.surface.default`, `color.border.subtle` |
| **spacing** | Margin, padding, gap | `space.1`–`space.12` on 4px or 8px grid |
| **typography** | Family, size, weight, line-height | `font.family.sans`, `font.size.sm`, `font.weight.medium` |
| **borders** | Radius, width | `radius.full`, `border.width.1` |
| **shadows** | Elevation | `elevation.1`, `elevation.modal` |
| **motion** | Duration, easing | `motion.duration.200`, `motion.easing.enter` |
| **z-index** | Stacking | `layer.base`, `layer.dropdown`, `layer.modal`, `layer.tooltip` |
| **breakpoints** | Viewport min-widths | `screen.sm`, `screen.md` (for doc; implementation uses px/rem) |

## Default values (illustrative — tune per brand)

| Token | Default |
|-------|---------|
| `space.1` | 4px |
| `space.4` | 16px |
| `radius.md` | 8px |
| `font.size.body` | 16px / 1.5 line-height |
| `motion.duration.200` | 200ms |
| `z.modal` | 1300 |

## Implementation

### React — CSS custom properties

```css
:root {
  --color-text-primary: #0a0a0a;
  --space-4: 1rem;
}
[data-theme="dark"] {
  --color-text-primary: #fafafa;
}
```

Consume in Tailwind v4 `@theme` or plain `var(--color-text-primary)`.

### Angular — global styles

- **`styles.scss`**: Define maps or CSS variables; components use `var(--token)` or mixins that read from the map.
- **Material** overrides: map component tokens to design tokens in a single theme file.

## Dark mode strategy

1. **Semantic tokens** (`color.bg`, `color.text`) swap per theme; **palette** tokens stay stable for charts.
2. **Toggle**: `prefers-color-scheme` default + user override stored in `localStorage` with `data-theme` on `<html>`.
3. **Contrast**: Re-verify **4.5:1** for text and **3:1** for UI components in both themes.
4. **Images/icons**: Prefer **SVG currentColor** or dual assets only when necessary.

## Rules

- Document **additions** in the same PR as the first component that needs them — avoid one-off hex in JSX/templates.
- **Version** token breaking changes in release notes — consumers may snapshot CSS variables.
