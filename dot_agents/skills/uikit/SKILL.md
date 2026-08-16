---
name: uikit
description: >-
  Build production UI that reads as a deliberate choice for this project rather than an LLM default, and audit shipped UI for the tells that give it away. Use when the user says "build this page", "make this UI not look AI-generated", "this looks like slop", "design this screen", "audit our UI", "make the frontend look good", or "/uikit". Reads a project's DESIGN.md when one exists; never writes it.
license: MIT
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
metadata:
  internal: false
---

# uikit

AI-generated UI has a signature. Three equal feature cards, a violet gradient, Inter on slate-900, a div-built fake dashboard in the hero, `01 / 02 / 03` eyebrows over content that isn't a sequence. None of these are bugs and no test catches them. They are **defaults — reached for because the model had no reason to reach anywhere else.**

uikit is the reason. It supplies the constraint that makes a UI decision *this project's* decision, and it names the tells so they can be avoided deliberately rather than reproduced accidentally.

The whole skill hangs off one idea: **taste is spent only where nothing else constrains the choice.** A project with a recorded design system gets consistency. A project with shipped components gets conformity. A greenfield project gets a point of view drawn from its own subject matter. None of them get a default. That is [the precedence ladder](#the-precedence-ladder), and every other section defers to it.

## What uikit is not

- **Not a design-system recorder.** `DESIGN.md` has one owner, and it isn't this skill. uikit reads it and never writes it — a skill that both invents the taste and records it can't be held to either job honestly.
- **Not a taste library.** No bundled palettes, no font pairings, no style catalog. A lookup table of 161 palettes is exactly how every project styled from it ends up looking like every other one.
- **Not the code reviewer.** Convention-fit, correctness, and completeness are a general review's job. uikit's audit is visual and interaction-level only.
- **Not a gate.** The pre-flight critiques its own output; it never fails a build. Taste is not a pass/fail check, and a build that can fail for it fails on something unfalsifiable.
- **Not an environment provisioner.** It never installs a browser, never starts a dev server it wasn't told to start, never seeds data.

## When this fires

- **`build`** — "build this page", "add a settings screen", "make this look good", "design the onboarding flow", or any UI work handed over by an implementation step. Generates the UI.
- **`audit`** — "does this look AI-generated", "audit our UI", "why does this feel like a template", "check the frontend for slop". Read-only sweep. **Writes nothing, ever.**

If a request is plainly one or the other, just run it. Ask only when a request could genuinely go either way ("look at the dashboard") — `audit` is free and `build` edits source.

## The precedence ladder

Four rungs. **Take the first that matches, and say which one it was before writing any code.** A lower rung never overrides a higher one; it only fills what the higher one leaves open.

| Rung | Matches when | What it constrains |
|---|---|---|
| **1 — `DESIGN.md`** | a `DESIGN.md` exists at the repo root | its tokens *are* the palette, type scale, spacing, and radii. Full stop. Its Do's and Don'ts are the voice rules for UI copy. |
| **2 — The shipped components** | a component directory, a `components.json`, or a token home (`@theme`, `:root` custom properties, a theme config) | the existing Button is the Button. Read three or four real components and match their composition, naming, and spacing habits. |
| **3 — The subject's own world** | neither of the above, but the product is knowable — README, a context file, route names, domain models, the actual thing being built | the product's materials, vocabulary, and artifacts. A tool for a print shop should not look like a tool for a hedge fund. |
| **4 — Stack defaults** | greenfield and the subject is genuinely opaque | the house default below, declared out loud as a default rather than a choice. |

**Rung 3 is where distinctiveness actually comes from.** Not from a style vocabulary — from the subject. Its instruments, its materials, its jargon, the artifacts the people who use it already handle. That is a well no other project can draw from, which is precisely why the result can't be generic.

### Signature materials by rung

The rung licenses *what the signature may be made of* — see [the design read](#the-design-read) for what the signature is:

- **Rungs 1–2** — composition, interaction, and motion. The tokens are fixed and are not yours to move. The room is in layout, in how the surface behaves, and in what it does at rest.
- **Rungs 3–4** — palette, type, and grid as well. Nothing is fixed, so the signature can be structural.

Rung 1 or 2 with a rung 3 palette is the single most damaging thing this skill could do: one rogue component that matches nothing around it, in a codebase that was consistent before you arrived.

## The design read

**Five declared words, stated before any code is written.** Cheap, and it is what stops the model jumping straight to a default aesthetic — a choice you have named out loud is a choice you can be argued out of.

```
Design read — surface: product · audience: internal ops staff · rung: 2 (shipped components)
· signature: the save affordance — rows commit on change and confirm in place, no page-level Save
· density: compact
```

| Word | Values | Why it's here |
|---|---|---|
| **surface** | `product` or `marketing` | the two have disjoint slop signatures; this is what filters [the catalog](#the-anti-slop-catalog) |
| **audience** | free text, concrete | "internal ops staff who live here 6 hours a day" implies different density than "a first-time visitor deciding in 8 seconds" |
| **rung** | `1`–`4` plus what matched | declares which constraint is in force and what the signature may be made of |
| **signature** | the one element this surface is remembered by, and its material | see below |
| **density** | `compact`, `comfortable`, `spacious` | the one axis that genuinely varies independently of the rung |

### The signature

**One element per surface. Exactly one.** The thing a person would describe if asked what the screen was like. Everything around it stays quiet and disciplined — spend your boldness in one place, and cut any decoration that doesn't serve the brief.

This is deliberately *not* framed as "take a creative risk." Asked to be bold, a model retrieves what boldness looks like, and what it retrieves is the **average** of every bold thing it has seen — which today means one of three looks: warm cream (near `#F4F1EA`) with a high-contrast serif and a terracotta accent; near-black with a single acid-green or vermilion accent; or a broadsheet layout with hairline rules, zero radius, and dense columns. All three are legitimate for *some* brief. None of them are a choice when they appear regardless of subject.

"Name the one thing this screen is remembered by" has no average to regress toward. It is also the only version that survives a pre-flight, which can check that **exactly one signature exists** and that **its materials are legal at the declared rung**, but cannot check whether a risk was taken.

Worked examples:

- **Rung 2, a settings page.** Default output: card, label-left/toggle-right rows, "Save changes" bottom-right. Correct and forgettable. Signature: *there is no Save button* — each row commits on change and confirms in place with an inline undo. Zero new tokens; the risk is real, because a slow network now has to be handled honestly.
- **Rung 3, a booking tool for a letterpress print shop.** Default output: Inter, slate-900, three feature cards, violet CTA. Signature: *the price list is a type specimen sheet* — sizes shown at their real sizes, ranged left on a baseline grid, palette drawn from paper stock and ink.

### Never block on the design read

**It is a declaration, not an interview.** When the subject is unclear at rung 3 or 4, infer it from whatever the repo shows and *state the inference* — never stop to ask. Wrong-but-stated beats correct-but-hung: uikit runs inside unattended pipelines where nothing is there to answer, and a stated read is the thing a reviewer corrects. Ask only when the user is plainly present and the request itself is ambiguous.

## Mode: `build`

### 1. Ground it

Walk [the ladder](#the-precedence-ladder) and name the rung that matched. Detect the stack from the project's manifest and config rather than assuming — framework, styling system, component library, and whether it's Tailwind v3 or v4, because [that distinction changes what renders](#the-stack-layer). Greenfield or undeclared, default to **Tailwind v4 + shadcn/ui** and say out loud that it's a default.

### 2. State the design read

[Five words](#the-design-read), one line, before any code exists.

### 3. Build

**Compose before you invent.** Use the existing component before writing a styled `div`; extend it before forking it; fork it only when the difference is real and say why. An agent's instinct is to write fresh markup because it's faster than reading what's there — that instinct is what produces a codebase with four Buttons.

- **Clear [the accessibility floor](#the-accessibility-floor)** without announcing it. It is a floor, not a feature.
- **Motion is justified in one sentence or it doesn't ship.** Animate `transform` and `opacity` only — never `transition: all`, never animate layout properties. One orchestrated moment beats scattered effects, and extra animation is itself a tell.
- **Write the strings as design material.** Follow `DESIGN.md`'s voice rules when it has them. Otherwise: active voice, sentence case, name things by what people control rather than how the system is built. A control says what happens — "Save changes", not "Submit" — and keeps the same verb through the whole flow, so a button that says "Publish" produces a toast that says "Published." Errors name the fix, not the failure. An empty screen is an invitation to act.
- **Match complexity to the direction.** Maximalist needs elaborate execution; minimal needs precision in spacing and type. Elegance is executing the chosen direction well, not choosing the smaller one.

### 4. Pre-flight

Run [self-critique](#self-critique). It is a critique, not a gate — findings get fixed or get named, and the build is not blocked either way.

### 5. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed** — the components and pages written or edited, one line each, and the composition decisions (what was reused, what was extended, what was newly written and why).

**Where it landed** — the file paths, and the pre-flight result including anything left unfixed.

**Next** — **repeat the design read verbatim in this hand-off.** It is the only durable record of why the UI looks the way it does, and repeating it here is what carries it into a PR body when this runs inside a pipeline. Then: if the project has no `DESIGN.md`, the crowned next move is **designkit** `init` when installed (otherwise write one by hand) — it derives the system from shipped UI, and there is now shipped UI to derive from. If a `DESIGN.md` already exists, the next move is committing the work with **commitkit** when installed, otherwise `git add` and commit. Changes are left unstaged either way; uikit does not commit.

## Mode: `audit`

**Read-only. Writes nothing, ever.** It reports and routes; fixing is a separate `build` invocation, deliberately.

### 1. Resolve the target

In order, taking the first that applies:

1. **Explicitly named paths** — a directory, a component, a route. This leads because the UI most worth auditing predates the skill and appears in no diff at all; "audit our UI" is the actual ask, and a diff cannot answer it.
2. **The UI files in the working tree or the branch diff** — when uncommitted or branch changes exist and no path was named. Note that a plain diff never shows untracked files, so list those separately and read them too.
3. **Ask** — when neither resolves. Don't sweep a whole repository by reflex; that's unbounded on any real application.

State the target in one line before reading anything.

### 2. Sweep

Run [the catalog](#the-anti-slop-catalog), filtered to the surface — `product` entries don't fire on a marketing page and `marketing` entries don't fire on a settings screen. Then [the accessibility floor](#the-accessibility-floor), which fires on both.

### 3. Report

Terse, clickable, no preamble. One finding per line:

```
src/components/Features.tsx:34   🔴  three equal feature cards for four features — show the real count, grouped by weight
src/components/Hero.tsx:12       🔴  fake dashboard built from divs — use a real screenshot or an embedded live component
src/app/settings/page.tsx:88     🟡  icon-only button with no accessible name — add aria-label
src/components/Card.tsx:7        🟢  rounded-3xl here, rounded-lg everywhere else — pick one corner language
```

🔴 Blocker · 🟡 Should-fix · 🟢 Nit. Then a mechanical verdict, and — **mandatory** — a coverage line: how many files were read and how many were skipped. An audit that reached three files reads exactly like a clean bill of health unless it says otherwise.

**On the seam with a general code review:** a code-review pass hunts *code* signatures — dead abstractions, over-commenting, defensive noise. uikit hunts *visual* ones. Running both against the same diff produces complementary findings, not duplicates. Neither defers to the other.

### 4. Hand off

**What changed** — nothing. Say it outright; a reader should never have to wonder whether a read-only mode wrote something.

**Where it landed** — inline in this reply. No artifact by default; offer to save one only if asked.

**Next** — crown the single worst finding and route it to [`build`](#mode-build). **"Nothing here reads as generated" is a valid, stated result** — say the UI is clean and stop rather than inventing a finding to justify the run.

## The anti-slop catalog

**The discipline is the point, and it travels with the list.** A tell earns a line only if it is stateable as a **ban with the correct alternative beside it**, *and* an agent can **check its own output for it without rendering anything**. The cap is **~30 entries, enforced by displacement: adding one means deleting one.** Lists like this rot into hundred-item checklists that nobody honestly ticks, and a checklist nobody ticks is decoration. A capped list that can only improve is worth more than an exhaustive one that can only grow.

Scope tags: **P** product · **M** marketing · **B** both.

### Visual and CSS

| | Ban | Instead |
|---|---|---|
| B | Violet/purple gradient as the accent, on the hero or the primary CTA | the project's own accent; at rung 3–4, a color the subject actually implies |
| B | Gradient text on headings | solid color — reach for weight or size when a heading needs emphasis |
| B | Glassmorphism by reflex: `backdrop-blur` over translucent white cards | an opaque surface with a real border |
| B | A drop shadow on every surface | shadow marks elevation; a card sitting in normal flow has none |
| B | `rounded-2xl`/`rounded-3xl` on everything | one corner language, taken from the system |
| B | Decorative status dots — a pulsing green dot bound to nothing | bind it to real state, or delete it |

### Typography

| | Ban | Instead |
|---|---|---|
| B | Inter (or the bare system stack) on slate-900 as the entire type decision | name a display face and a body face deliberately; make the type treatment part of the design, not a delivery vehicle |
| M | An eyebrow/kicker label above every heading | delete it — if the section needs context, the heading carries it |
| M | `01 / 02 / 03` numbered markers on content that is not a sequence | use them only when order is information the reader needs |
| B | Em-dashes in **interface strings** | a period, a comma, or two sentences. This governs strings on screen, not prose in the repo |
| B | All-caps letterspaced micro-labels scattered as texture | one label style, used where a label is genuinely needed |

### Layout

| | Ban | Instead |
|---|---|---|
| B | Three equal feature cards | show the real count, sized by real weight — four features get four |
| M | Every section centered, `max-w` + `mx-auto` + `text-center` all the way down | vary alignment; centering is for the one thing that deserves it |
| M | A `Scroll ↓` cue or bouncing chevron | delete it — content bleeding past the fold does that job |
| M | Decorative hairline grids or dot-pattern backgrounds | delete; structure should encode something true, not decorate |
| M | Rotated vertical text down the side of a section | delete |
| M | A locale / weather / local-time strip | delete, unless the product is genuinely about time or place |

### Content and copy

| | Ban | Instead |
|---|---|---|
| B | "Jane Doe" / "John Smith" placeholder people | names from the product's own domain, or the real empty state |
| M | An "Acme Inc / Company Name" logo row | real customers, or cut the section until they exist |
| M | Invented metrics — "99.99% uptime", "10,000+ users", "2M requests" | real numbers, or no numbers |
| B | Lorem ipsum | real copy; when it's unknown, the shortest true sentence |
| M | Testimonial cards with invented quotes and stock avatars | cut the section until real ones exist |

### Fake product

| | Ban | Instead |
|---|---|---|
| M | A dashboard or app screenshot built out of `div`s | a real screenshot, an embedded live component, or nothing |
| M | Fake browser chrome wrapped around a mock | same — a fake window frame is the most recognizable tell on the list |

### Product-UI state gaps

Silence in these is the product-side equivalent of a purple gradient — nobody designed it, it's just what got generated.

| | Ban | Instead |
|---|---|---|
| P | A list or table that renders nothing at zero rows | an empty state naming the thing and offering the action that creates one |
| P | No loading state | a skeleton matching the real layout, or a labeled loading region |
| P | No error state | an error naming what failed and the recovery action |
| P | Icon-only buttons with no accessible name | `aria-label`, plus a tooltip when the icon isn't obvious |
| P | "Invalid input" as validation copy | name the constraint and the fix — "Password needs 12+ characters" |
| P | A disabled control with no stated reason | say why it's disabled, or don't disable it |
| P | Destructive actions with no confirmation and no undo | confirm, or make it undoable — undo is usually better |

## The accessibility floor

Not findings — a floor. Every build clears these without announcing it, and `audit` reports any that a shipped surface doesn't:

- Visible `:focus-visible` on every interactive element. Never remove a focus ring without replacing it.
- `prefers-reduced-motion` honored wherever anything moves.
- WCAG AA contrast on text and on meaningful non-text.
- Semantic elements before ARIA — a `button` beats a `div` with `role="button"` and a click handler, always.
- Every control labeled, every image with `alt` (empty `alt=""` when decorative, deliberately).
- Everything reachable and operable by keyboard, in a sane tab order, with focus trapped in modals and restored on close.
- Touch targets no smaller than 44px on coarse pointers.

## The stack layer

The house default, and skippable whole by a project on another stack. These are correctness rules that prevent *silent* wrongness, not style preferences.

### Tailwind v4

v4 is CSS-first. Theme lives in `@theme` inside the stylesheet, not in a JS config: `@import "tailwindcss"`, then `@theme`, `@utility`, `@custom-variant`, `@source`, and `@reference` when a separate stylesheet needs the theme.

**These renames are the reason to check the version first.** Every one of them is a valid class name in v4 that renders *smaller* than the author intended — no error, no warning, just a subtly wrong result that reads as a design decision:

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

Prefer a generated utility over an arbitrary value (`p-4`, not `p-[16px]`) and a variant over hand-written CSS — arbitrary values are how a design system quietly stops being one.

### shadcn/ui

- **Install through the CLI; don't hand-copy component source.** The components are yours to edit after they land, but the initial copy should be the real one.
- **`className` adjusts layout, not appearance.** Margin, width, grid placement — yes. Restyling the component's internals from the outside means the variant should have been extended instead.
- **Semantic tokens only** — `bg-background`, `text-muted-foreground`, `bg-primary`. Never a raw `bg-blue-500` on a shadcn surface.
- **No manual `dark:` overrides.** Semantic tokens already flip. A `dark:` override on a token-styled element means the token was wrong.
- **`gap-*` inside a flex or grid container, never `space-x-*`/`space-y-*`.**
- **`size-*` over `w-N h-N`** when both are equal, and `truncate` over the three-property longhand.
- **`cn()` for conditional classes** — never string concatenation, which breaks conflict resolution.
- **No manual `z-index` on overlays.** Dialog, Sheet, Popover, and Dropdown manage their own stacking; a hand-set z-index is how one ends up behind another.
- **Forms compose as `FieldGroup` → `Field`**, and items live inside their group (`SelectItem` in `SelectGroup`, and so on).
- **`asChild` (Radix) or `render` (Base UI) for triggers** — never a nested button inside a trigger.
- **Dialog, Sheet, and Drawer each need a title**, visually hidden if the design doesn't show one. A screen reader announcing an unnamed dialog is a dead end.
- **Cards compose fully** — header, title, content, footer — rather than a bare `Card` with markup dumped inside.

## Self-critique

### The written pre-flight — always runs

The default, and the one that actually fires in headless CI and locked-down VMs. Check the output against:

1. **The catalog**, filtered to the declared surface.
2. **The accessibility floor**, all of it.
3. **The two signature checks** — exactly one signature exists, and its materials are legal at the declared rung.
4. **The remove-one-accessory pass.** Before shipping, look at what you built and take one thing away. There is nearly always one decoration that doesn't serve the brief, and it is nearly always easier to see at the end than at the start.

Report what you fixed and what you're leaving, with a reason. This is a critique, not a gate — it never blocks the build.

### The pixel pass — opt-in

Only on an explicit ask ("look at it", "screenshot it and check"). A picture is worth a thousand tokens when a picture is available.

Use what is **already present**, in this order: a browser-automation tool the environment provides · an installed headless browser or an existing test-automation setup already in the project. Point it at whatever renders cheapest — a static file, a component preview route, a running dev server the user started.

**Never install a browser. Never start a dev server you weren't told to start. Never seed data.** uikit needs strictly less than a full end-to-end tool does: rendered output, not a driven authenticated flow.

## Degrade loudly

No browser, no rendering, no filesystem — these are normal conditions, not errors. **Name the gap in the same breath as the result**, and never frame the written pre-flight as a failed screenshot:

> Built `SettingsPanel.tsx` and `SettingsRow.tsx`. Pre-flight clean against the product catalog and the a11y floor. No visual check — no browser automation available in this environment.

Never claim a visual check that didn't happen. A UI reported as verified when nothing looked at it is worse than one reported as unverified.

No filesystem at all (a browser-based agent)? Print each component as a fenced block labelled with its intended path, state the design read as normal, and name the commands the user should run themselves.

## Notes

- **The ladder outranks the taste.** When the recorded system and your better idea disagree, the system wins and the better idea goes in the hand-off as a suggestion. Consistency compounds; a one-off improvement doesn't.
- **Composition outranks invention.** The existing component, then an extension of it, then something new — in that order, with a reason at each step down.
- **Never invent data.** A number, a name, a logo, or a quote that isn't real doesn't ship, even as a placeholder. Placeholder data has a way of surviving to production, and inventing a metric is the one tell that can embarrass someone.
- **Existing project convention wins.** A repo with its own component patterns, file layout, or styling approach gets followed — and uikit says which convention it followed.
- **UI copy here, prose elsewhere.** uikit governs the strings inside the interface. Repo prose, docs, and READMEs belong to a general prose pass — **humankit** when installed.
- **Does not commit.** Changes are left unstaged for a commit step to group.
