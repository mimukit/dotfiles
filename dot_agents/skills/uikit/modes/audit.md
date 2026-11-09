# Mode `audit`: sweep shipped UI for the tells

**Read-only. Writes nothing, ever.** It reports and routes; fixing is a separate `build` invocation, deliberately.

### 1. Resolve the target

In order, taking the first that applies:

1. **Explicitly named paths**, meaning a directory, a component, or a route. This leads because the UI most worth auditing predates the skill and appears in no diff at all; "audit our UI" is the actual ask, and a diff cannot answer it.
2. **The UI files in the working tree or the branch diff**, when uncommitted or branch changes exist and no path was named. Note that a plain diff never shows untracked files, so list those separately and read them too.
3. **Ask**, when neither resolves. Don't sweep a whole repository by reflex; that's unbounded on any real application.

State the target in one line before reading anything. This step is done when the target line names every path in scope.

### 2. Sweep

Run [the catalog](../SKILL.md#the-anti-slop-catalog), filtered to the surface, so `product` entries don't fire on a marketing page and `marketing` entries don't fire on a settings screen. Then run [the accessibility floor](../SKILL.md#the-accessibility-floor), which fires on both, and [the mobile layer](../SKILL.md#the-mobile-layer) when the surface ships to phones. This step is done when every file in the target has been checked against every filtered catalog entry, every floor rule, and every mobile fix that applies, or is counted as skipped.

### 3. Report

Terse, clickable, no preamble. One finding per line:

```
src/components/Features.tsx:34   🔴  three equal feature cards for four features → show the real count, grouped by weight
src/components/Hero.tsx:12       🔴  fake dashboard built from divs → use a real screenshot or an embedded live component
src/app/settings/page.tsx:88     🟡  icon-only button with no accessible name → add aria-label
src/components/Card.tsx:7        🟢  rounded-3xl here, rounded-lg everywhere else → pick one corner language
```

🔴 Blocker · 🟡 Should-fix · 🟢 Nit. Then a mechanical verdict, and a **mandatory** coverage line: how many files were read and how many were skipped. An audit that reached three files reads exactly like a clean bill of health unless it says otherwise.

**On the seam with a general code review:** a code-review pass hunts *code* signatures, meaning dead abstractions, over-commenting, and defensive noise. uikit hunts *visual* ones. Running both against the same diff produces complementary findings, not duplicates. Neither defers to the other.

### 4. Hand off

**What changed.** Nothing. Say it outright; a reader should never have to wonder whether a read-only mode wrote something.

**Where it landed.** Inline in this reply. No artifact by default; offer to save one only if asked.

**Next.** Crown the single worst finding and route it to [`build`](build.md). An extra or scattered animation finding routes to `motionkit review` when motionkit is installed, and motionkit judges whether to keep, change, or remove it. **"Nothing here reads as generated" is a valid, stated result**, so say the UI is clean and stop rather than inventing a finding to justify the run.
