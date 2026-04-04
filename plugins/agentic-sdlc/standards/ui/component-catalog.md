# Component Catalog — Atoms, Molecules, Organisms, Templates

Prop types use **TypeScript**-style notation. Adapt to your codebase (Angular: `@Input()` equivalents).

---

## Atoms

### Button
- **Props**: `variant: 'primary' | 'secondary' | 'ghost' | 'danger'`, `size: 'sm' | 'md' | 'lg'`, `disabled?: boolean`, `loading?: boolean`, `type?: 'button' | 'submit' | 'reset'`, `children: ReactNode`, `onClick?: () => void`, `ariaLabel?: string` (if icon-only)
- **Behavior**: `disabled` + `loading` stops interaction; spinner replaces or augments label when `loading`.

### Input
- **Props**: `value`, `defaultValue?`, `onChange`, `placeholder?`, `disabled?`, `invalid?: boolean`, `id: string`, `name?: string`, `type?: 'text' | 'email' | 'password' | 'number' | 'search'`, `autoComplete?: string`
- **A11y**: Pair with external `<label htmlFor={id}>` or `aria-label`.

### Checkbox
- **Props**: `checked: boolean | 'indeterminate'`, `onChange`, `disabled?`, `id: string`, `name?: string`, `label?: ReactNode`
- **A11y**: Native checkbox with visible label; `aria-checked` for custom implementations.

### Radio
- **Props**: `name: string` (group), `value: string`, `checked: boolean`, `onChange`, `disabled?`, `label?: ReactNode`
- **A11y**: Wrap in `radiogroup` with `aria-labelledby` when no visible legend.

### Toggle (Switch)
- **Props**: `checked: boolean`, `onChange`, `disabled?`, `ariaLabel: string` (required if no visible label)
- **A11y**: `role="switch"` if not native; keyboard Space/Enter.

### Badge
- **Props**: `variant: 'neutral' | 'success' | 'warning' | 'danger'`, `children: ReactNode`, `dot?: boolean`

### Spinner
- **Props**: `size?: 'sm' | 'md' | 'lg'`, `label?: string` (for `aria-label`)

### Icon
- **Props**: `name: IconName`, `size?: number | 'sm' | 'md'`, `decorative?: boolean` — if decorative, `aria-hidden="true"`

### Avatar
- **Props**: `src?: string`, `alt: string`, `fallback?: string` (initials), `size?: 'sm' | 'md' | 'lg'`

### Tooltip
- **Props**: `content: ReactNode`, `children: ReactNode`, `placement?: 'top' | 'bottom' | 'left' | 'right'`, `delay?: number`
- **A11y**: Trigger must be focusable; content in portal with `role="tooltip"` linked via `aria-describedby` on hover/focus.

---

## Molecules

### FormField
- **Props**: `label: string`, `htmlFor: string`, `error?: string`, `hint?: string`, `required?: boolean`, `children: ReactNode` (control)
- **Pattern**: Renders label, control slot, hint `id`, error `id` wired to `aria-describedby` / `aria-invalid`.

### SearchBar
- **Props**: `value`, `onChange`, `onSubmit`, `placeholder?`, `loading?`, `clearable?: boolean`

### Card
- **Props**: `title?: ReactNode`, `description?: ReactNode`, `footer?: ReactNode`, `padding?: 'none' | 'sm' | 'md' | 'lg'`, `children: ReactNode`

### Alert
- **Props**: `variant: 'info' | 'success' | 'warning' | 'error'`, `title?: string`, `children: ReactNode`, `onDismiss?: () => void`, `role?: 'status' | 'alert'`

### Breadcrumb
- **Props**: `items: { label: string, href?: string }[]` — last item not a link; `nav` with `aria-label="Breadcrumb"`.

### Pagination
- **Props**: `page: number`, `pageSize: number`, `total: number`, `onPageChange`, `onPageSizeChange?`
- **A11y**: `aria-current="page"` on active; buttons have discernible names.

### Tabs
- **Props**: `tabs: { id: string, label: string, content: ReactNode }[]`, `defaultTabId?`, `onChange?`
- **A11y**: Tablist/tabpanel pattern with roving tabindex.

### Dropdown (Menu)
- **Props**: `trigger: ReactNode`, `items: { label, onClick, disabled?, destructive? }[]`, `align?: 'start' | 'end'`
- **A11y**: `menu` / `menuitem`; Escape closes; typeahead optional.

### DatePicker
- **Props**: `value: Date | null`, `onChange`, `minDate?`, `maxDate?`, `disabled?`, `locale?`
- **A11y**: Grid role for calendar; keyboard date navigation.

---

## Organisms

### DataTable
- **Props**: `columns: ColumnDef<T>[]`, `data: T[]`, `sortable?`, `onSort?`, `pagination?`, `loading?`, `emptyState?`, `getRowId: (row: T) => string`
- **Behavior**: Virtualization optional prop; sticky header optional.

### Modal
- **Props**: `open: boolean`, `onClose`, `title: string`, `size?: 'sm' | 'md' | 'lg' | 'full'`, `children`, `footer?: ReactNode`
- **A11y**: Focus trap, Escape, `aria-modal="true"`, labelledby title id.

### Drawer
- **Props**: `open`, `onClose`, `side?: 'left' | 'right'`, `title?`, `children`
- **A11y**: Same as modal where overlay pattern applies.

### Form (generic)
- **Props**: `onSubmit`, `children`, `id?: string` — composes FormFields; handles `noValidate` + RHF submit bridge.

### Header
- **Props**: `logo`, `navItems`, `actions?`, `mobileMenu?: boolean`

### NavigationMenu
- **Props**: `items: NavItem[]` (nested allowed), `orientation?: 'horizontal' | 'vertical'`
- **A11y**: Menubar/disclosure pattern per WAI-ARIA APG.

---

## Templates

### AuthLayout
- **Slots**: `children` (form), optional `aside` (illustration), `brand`
- **Use**: Centered column, max-width token, background surface.

### DashboardLayout
- **Slots**: `sidebar`, `header`, `main`, `footer?`
- **Use**: Responsive collapse of sidebar.

### ListDetailLayout
- **Slots**: `list`, `detail` — stack on mobile; split `md+`.

### FormPageLayout
- **Slots**: `title`, `description`, `children`, `actions` (sticky footer optional)

### EmptyState
- **Props**: `icon?`, `title`, `description?`, `primaryAction?`, `secondaryAction?`

### ErrorPage
- **Props**: `statusCode?: number`, `title`, `message`, `retry?`, `homeHref?`

---

## Usage rules

- **Atoms** live in `shared/components/ui/`; **templates** in `shared/templates/` or `features/*/layouts/`.
- Every organism **documents** required data contracts (TypeScript generics for DataTable).
- New components **extend** this catalog in PR — add row to this file when introducing primitives.
