## Mode: `review`

**Read-only. Writes nothing, ever.** It judges motion at the scale of its target: a change gets a findings table and a verdict, and a codebase sweep gets a ranked list with one crowned item. A fix is a separate `build` run, so the person who reads the report decides what to change. A uikit audit may route an "extra animation" finding here; this mode judges whether that motion stays, changes, or goes.

**Flag by default; approval is earned.** Motion that runs is not motion that passes. A transition that lands late, grows from the wrong point, fires on a high-frequency action, or restarts on a second trigger is a finding even when nothing breaks. **Restraint is the bar for new motion.** Daily use argues for less, so expect to reject most candidates, and treat "the motion here is already right" as a result worth stating.

### 1. Resolve the target and its scale

Take the first source that applies:

1. **Named paths**, such as a component, a stylesheet, or a route. A named file or component is **change** scale; a named directory or app is **sweep** scale.
2. **A sweep ask** ("audit the animations in this app", "what should animate here", "make the app feel alive"). **Sweep** scale over the app's interactive UI: components, routes, and styles, with tests, stories, and build output excluded. Ask when the repo holds several apps and the ask names none.
3. **The working tree**, when it holds uncommitted changes: `git diff` plus `git diff --cached`, and the untracked files from `git status --porcelain`, which a plain diff never shows. **Change** scale.
4. **The branch against its base**, when the tree is clean: `git diff <base>...HEAD`, with the base from `gitkit` when installed, otherwise `origin/HEAD`. **Change** scale.
5. **Ask**, when none resolves.

State the target and its scale in one line, then run [Stack detection](../SKILL.md#stack-detection). **Done when** the target line names every file or directory in scope, its scale, and the stack line names the drivers and token homes.

### 2. Recon

Read each file in scope in full, not only the changed hunks, because a hunk that changes a duration can hide the `transition: all` three lines above it. Build two lists:

- **Every animation.** `transition` and `animation` declarations, `@keyframes`, `@starting-style`, Tailwind `transition-*`, `duration-*`, `ease-*`, and `animate-*` classes, Motion `animate`, `initial`, `exit`, and `transition` props, `.animate(` calls, `useSpring`, and `requestAnimationFrame` loops. Record `file:line`, the element it moves, and the trigger that starts it.
- **Every motion-free interactive surface.** Pressables with no `:active` state, conditional renders with no transition (`{open &&`, `hidden` toggles), accordions and `details`, popovers and menus, toasts and sheets, lists that gain or lose items, drag handlers, and empty, success, and first-run states. At change scale, list only the surfaces the change adds or touches.

Place each entry from both lists on a tier of [The frequency gate](../SKILL.md#the-frequency-gate). At sweep scale, also decide whether the product reads as a crisp tool or a playful app, because [Cohesion with tokens](../SKILL.md#cohesion-with-tokens) depends on it. **Done when** both lists are complete for the target, or state "no motion in scope", and every entry carries `file:line` and a frequency tier.

### 3. Judge each animation against the standard

Walk every animation through [the motion standard](../SKILL.md#the-motion-standard), top heading to bottom. A rule that the project's own token or documented convention overrides is not a finding; note the override once.

Escalate these on sight, at the highest severity:

- `ease-in` on an entrance, an exit, or any response to input ([Easing](../SKILL.md#easing)).
- An entrance from `scale(0)`, or a pure fade with no starting transform ([Physicality and origin](../SKILL.md#physicality-and-origin)).
- A trigger-anchored popover, menu, or tooltip that scales from its own center.
- `transition: all`, or a layout property animated where a transform tier exists ([Property cost](../SKILL.md#property-cost)).
- Keyframes on UI a user can trigger again mid-motion, such as toasts, toggles, and tabs ([Interruptibility](../SKILL.md#interruptibility)).
- Any animation on a keyboard shortcut, the command palette, or another action at the top frequency tier.
- UI motion over 300 ms with no stated reason ([Duration](../SKILL.md#duration)).
- Movement with no reduced-motion path, or hover motion with no fine-pointer gate ([Reduced motion and pointer gating](../SKILL.md#reduced-motion-and-pointer-gating)).
- A parent CSS variable that drives a child's `transform`.

Label each finding per [Guards](../SKILL.md#guards). A claim about feel or smoothness from code alone is "needs a recording". When a browser driver is present, record the doubtful ones and relabel them "recorded". **Done when** every animation has a finding or an explicit pass, and every finding has a standard heading and a label.

### 4. Gate the missing motion

Put each motion-free surface through four gates, in order. A candidate that fails one gate is rejected at that gate:

1. **Frequency.** The surface sits at the occasional or rare tier. A keyboard-initiated action fails outright.
2. **Purpose.** It names one purpose from [Purpose](../SKILL.md#purpose); delight passes only at the rare tier.
3. **Speed.** The motion works inside its band in [Duration](../SKILL.md#duration). A moment that only works slow and showy fails.
4. **Function.** Motion helps the person here. Data a person reads or acts on fails.

**Done when** every motion-free surface is a survivor or a rejection with its gate.

### 5. Choose the fix by the remedy order

For each finding, take the earliest remedy that resolves it:

1. **Remove the motion.** This applies when the animation fails the frequency gate or names no [Purpose](../SKILL.md#purpose).
2. **Fix the ingredient.** Change the curve, the duration, the origin, the starting transform, the property, the driver (keyframes to a transition or spring), or the timing asymmetry.
3. **Add what is missing.** Add the reduced-motion path, the hover gate, a stagger, or a blur mask on a crossfade.

Give each survivor from the gates a recipe: the properties, the curve, the duration, the origin, and the reduced-motion behavior. Give exact values throughout: the curve as a token or a `cubic-bezier()`, the duration in milliseconds, the property list. Reuse the project's tokens. **Done when** every finding has one fix and every survivor one recipe, with exact values, and no fix uses a later remedy where an earlier one works.

### 6. Vet, then rank

Reread the cited lines for every finding and survivor. Drop an item that is by design (a centered modal, a long beat on a marketing page), duplicated, misattributed, or covered by a documented project decision. Rank the kept items: at change scale, by severity, escalation triggers first; at sweep scale, by leverage, the felt effect times how often people meet it, against the size of the change, so a fix to a shared token or primitive outranks a fix to one screen. **Done when** every kept item is confirmed at its `file:line` and holds a rank.

### 7. Report

One table, one row per kept item, in rank order:

```
| # | file:line | Kind | Finding | Standard rule | Fix or recipe | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | src/Toast.tsx:41 | fix | Toast enters on @keyframes; a second toast restarts the first | Interruptibility | Transition transform and opacity, 200ms var(--ease-out), start in @starting-style | from code |
| 2 | src/menu.css:12 | fix | Menu enters with ease-in 320ms from scale(0) | Easing | ease-out var(--ease-out), 180ms, from scale(0.96) opacity 0, origin var(--transform-origin) | from code |
```

Then, by scale:

- **Change scale: the verdict.** **Block** when any escalation trigger fired or a finding needs the first remedy. **Pass** when none fired, durations and curves sit inside the standard, interruptible UI uses transitions or springs, and every movement has a reduced-motion path.
- **Sweep scale: rejected candidates.** This section is required. List every surface considered for new motion and rejected, with its gate, plus each existing animation that should stay as it is. With no candidates, state why the sweep found none.

Close with a coverage line: files read, animations judged, surfaces gated, findings by label. **Done when** the table, the verdict or the rejected list, and the coverage line are in the reply.

### 8. Hand off

**What changed.** Nothing. State that this review wrote no file.

**Where it landed.** The report is in this reply.

**Next.** Crown item 1 alone, by its `file:line`. Fix it with **motionkit `build`**: "fix the toast entrance at `src/Toast.tsx:41`". When the verdict is pass or no item survives, say that the motion passes the standard and stop.
