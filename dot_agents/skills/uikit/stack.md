## The stack layer

The house default, and skippable whole by a project on another stack. These are correctness rules that prevent *silent* wrongness, not style preferences.

### Tailwind v4

v4 is CSS-first. Theme lives in `@theme` inside the stylesheet, not in a JS config: `@import "tailwindcss"`, then `@theme`, `@utility`, `@custom-variant`, `@source`, and `@reference` when a separate stylesheet needs the theme.

**These renames are the reason to check the version first.** Every one of them is a valid class name in v4 that renders *smaller* than the author intended, with no error, no warning, just a subtly wrong result that reads as a design decision:

| v3 | v4 |
|---|---|
| `shadow-sm` | `shadow-xs` |
| `shadow` | `shadow-sm` |
| `rounded-sm` | `rounded-xs` |
| `rounded` | `rounded-sm` |
| `blur-sm` | `blur-xs` |
| `blur` | `blur-sm` |
| `outline-none` | `outline-hidden` |
| `ring` | `ring-3` |
| `bg-gradient-to-r` | `bg-linear-to-r` |
| `!text-center` | `text-center!` |

Prefer a generated utility over an arbitrary value (`p-4`, not `p-[16px]`) and a variant over hand-written CSS, because arbitrary values are how a design system quietly stops being one.

### shadcn/ui

- **Install through the CLI; don't hand-copy component source.** The components are yours to edit after they land, but the initial copy should be the real one.
- **`className` adjusts layout, not appearance.** Margin, width, and grid placement are fine. Restyling the component's internals from the outside means the variant should have been extended instead.
- **Semantic tokens only**, meaning `bg-background`, `text-muted-foreground`, `bg-primary`. Never a raw `bg-blue-500` on a shadcn surface.
- **No manual `dark:` overrides.** Semantic tokens already flip. A `dark:` override on a token-styled element means the token was wrong.
- **`gap-*` inside a flex or grid container, never `space-x-*`/`space-y-*`.**
- **`size-*` over `w-N h-N`** when both are equal, and `truncate` over the three-property longhand.
- **`cn()` for conditional classes**, never string concatenation, which breaks conflict resolution.
- **No manual `z-index` on overlays.** Dialog, Sheet, Popover, and Dropdown manage their own stacking; a hand-set z-index is how one ends up behind another.
- **Forms compose as `FieldGroup` → `Field`**, and items live inside their group (`SelectItem` in `SelectGroup`, and so on).
- **`asChild` (Radix) or `render` (Base UI) for triggers**, never a nested button inside a trigger.
- **Dialog, Sheet, and Drawer each need a title**, visually hidden if the design doesn't show one. A screen reader announcing an unnamed dialog is a dead end.
- **Cards compose fully** (header, title, content, footer) rather than a bare `Card` with markup dumped inside.
