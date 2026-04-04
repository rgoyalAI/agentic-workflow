# WCAG 2.1 Level AA — Code-Level Checklist

Use this checklist for **implementation** and **automated PR gates**. Criteria map to WCAG 2.1 AA success criteria where applicable.

## Checklist

| Requirement | WCAG / practice | Implementation | Test |
|-------------|-----------------|----------------|------|
| **Color contrast** | 1.4.3 Contrast (Minimum) | Text/UI: **4.5:1** normal text, **3:1** large text & graphical UI components | Automated: `axe-core`; manual spot-check with contrast tool |
| **Keyboard navigation** | 2.1.1 Keyboard, 2.1.2 No Keyboard Trap | All interactive controls reachable with **Tab**/**Shift+Tab**; modals trap focus **inside** until closed | E2E: keyboard-only path; focus trap unit tests |
| **Focus visible** | 2.4.7 Focus Visible | **2px+** visible outline or equivalent; never `outline: none` without replacement | Visual regression; axe rule |
| **ARIA roles & names** | 4.1.2 Name, Role, Value | Interactive elements have **accessible name**; custom widgets use correct **role** and **state** | axe; screen reader smoke |
| **Form labels & errors** | 3.3.1 Error Identification, 3.3.2 Labels or Instructions | `<label>` or `aria-label`; errors in text + `aria-invalid` + `aria-describedby` | Unit + E2E fill invalid forms |
| **Heading order** | 1.3.1 Info and Relationships | Logical **h1→h2→h3** per page; one `h1` main title | axe `heading-order`; manual |
| **Language** | 3.1.1 Language of Page | `<html lang="en">` (or correct code) | HTML validator |
| **Motion reduction** | 2.3.3 Animation from Interactions | Respect **`prefers-reduced-motion`**: reduce parallax, auto-play | CSS media query + E2E flag |
| **Touch targets** | 2.5.5 Target Size (AAA aspirational) / best practice | Minimum **44×44 CSS px** for primary actions | Design review + CSS audit |
| **Screen reader announcements** | 4.1.3 Status Messages | Toasts/loading use **`role="status"`** or **`aria-live`** appropriately | Manual NVDA/VoiceOver |

## axe-core integration

- **Unit / component**: `@axe-core/react` in test utils for critical shared components.
- **E2E**: Run axe after navigation and key interactions (Playwright + `@axe-core/playwright`).
- **CI**: Fail build on **serious/critical** violations unless tracked waiver with expiry.

## Focus management

- **Modal open**: Move focus to first focusable; **return focus** to trigger on close.
- **Route change**: Move focus to **`h1`** or main container (`tabindex="-1"` programmatic focus).
- **Dropdowns**: **Escape** closes; arrow keys move within listbox pattern.

## Error identification

- Errors **not** conveyed by color alone — include icon/text.
- **Form-level** error summary at top with links to fields for long forms.

## Language declaration

- Set **`lang`** on document; mark inline language switches with `lang` on spans when mixed-language content.

## Motion reduction

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

Prefer **conditional rendering** of non-essential motion over blanket overrides that break dialogs.

## Sign-off

- **Design** approves contrast and touch targets.
- **Engineering** attaches axe report artifact to release for major UI changes.
