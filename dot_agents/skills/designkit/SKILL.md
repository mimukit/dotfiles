---
name: designkit
description: >-
  Derive a project's design system from the UI it already ships and keep it true as the code moves, producing a spec-compliant DESIGN.md at the repo root, validated by the official linter. Use when the user says "write a DESIGN.md", "document our design system", "extract our design tokens", "our design system is out of date", "audit our design tokens", "what colors does this project actually use", "sync DESIGN.md to our Tailwind theme", or "/designkit".
license: MIT
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
metadata:
  internal: false
---

# designkit

A design system that lives in someone's head, or in Figma, is invisible to the agent writing the UI. `DESIGN.md` is what the ecosystem converged on instead: an open format from Google Labs (Apache-2.0, [google-labs-code/design.md](https://github.com/google-labs-code/design.md)) that pairs machine-readable design tokens in YAML front matter with human-readable rationale in prose. It is deliberately the design counterpart to the agent instruction files coding agents already read (`CLAUDE.md` and its equivalents), a persistent contract in the repo root that survives sessions, and that any DESIGN.md-aware agent reads.

designkit does the half the ecosystem left empty. Every other tool hands you a design system from *somewhere else*, whether a file reverse-engineered from Stripe or a palette retrieved from a product-type lookup table. **designkit derives yours from the UI you already shipped, and tells you later when it has gone stale.**

That makes the grounding rule the whole skill: **every token must be a value that appears in your codebase.** The one exception is a repo with no UI at all, where there is nothing to derive from; there, every token is a value you supplied (see [`init`'s interview](#2-interview-only-when-theres-nothing-to-read)), and designkit still invents none. Clustering forty near-identical greys into a scale is derivation. Picking a nicer neighbouring hex because it rounds better is invention, and it is the one thing designkit never does.

## What designkit is not

- **Not a UI generator.** It records the system; it writes no components, no pages, no application CSS. A skill that both defines the taste and applies it can't be held to the grounding rule.
- **Not a taste library.** It ships no palettes, no font pairings, no style catalog. If your project has no design system, designkit proposes one from the values your code already uses, or, with no UI at all, from the values you supply; when neither exists it says so. It never imports someone else's.
- **Not a spec implementation.** Linting, contrast checking, token export, and the schema itself belong to the official CLI. designkit shells out and reports; it is not a second, worse implementation.
- **Not a design critique.** Whether the system is any *good* is a human's call. designkit reports what is there, including when what's there is a mess.
- **Not the glossary or the decision log.** Domain vocabulary and architecture decisions belong elsewhere; a design token is neither.

## When this fires

- **`init`.** "Write a DESIGN.md", "document our design system", "we have no design tokens", "what colors does this project actually use". Derives the file from the codebase.
- **`update`.** "The design system changed", "update DESIGN.md", or a design pass right after UI work lands. Applies what the code now says.
- **`audit`.** "Is our DESIGN.md still accurate", "check the design system against the code", "what's drifted". Read-only sweep. **Writes nothing, ever.**
- **`sync`.** "Sync DESIGN.md to our Tailwind theme", "export our tokens", or the follow-up `init` names when the file and the token home disagree. Writes the project's existing token home from `DESIGN.md`.

**If no mode is clear, ask.** `audit` is free and `init` rewrites the project's design contract; never guess between them.

What each mode may write:

| Mode | Writes | Gate |
|---|---|---|
| `init` | `DESIGN.md`; the swatch sheet and its `.gitignore` line | the proposal |
| `update` | token and prose edits in `DESIGN.md`; the swatch sheet and its `.gitignore` line when a gated change needs one | new sections, deletions, and drift outside the target |
| `audit` | nothing | none |
| `sync` | the existing token home (Tailwind theme, `:root` block) or a DTCG export file | every write |

## The artifact

`DESIGN.md` lives at the **repo root**. That's the spec's convention and how DESIGN.md-aware tools discover it, not `docs/`, however tempting the tidiness.

### The token schema

Front matter opens with a line of exactly `---` and closes the same way. This is the alpha schema as captured on 2026-08-06; prefer [reading it live](#the-cli-is-the-source-of-truth) when the CLI is available, because the format is explicitly still moving.

```yaml
version: <string>          # optional, current: "alpha"
name: <string>
description: <string>      # optional
omitted: <string[] | OmittedSection[]>   # optional; sections deliberately excluded
colors:
  <token-name>: <Color>            # "#1A1C1E", "oklch(62% 0.18 250)", CSS named
typography:
  <token-name>: <Typography>       # fontFamily, fontSize, fontWeight, lineHeight,
                                   # letterSpacing, fontFeature, fontVariation
rounded:
  <scale-level>: <Dimension>       # 4px, 0.5rem, 9999px
spacing:
  <scale-level>: <Dimension | number>
components:
  <component-name>:
    <token-name>: <string | token reference>   # "{colors.primary}"
```

Values cross-reference with `{path.to.token}` syntax. Prefer a reference over a repeated literal, because an unreferenced token trips `orphaned-tokens`, and a duplicated literal is how a system drifts.

**Recommended token names** (non-normative, but follow them unless the project already has its own vocabulary): colors `primary`, `secondary`, `tertiary`, `neutral`, `surface`, `on-surface`, `error`; typography `headline-display`, `headline-lg`, `headline-md`, `body-lg`, `body-md`, `body-sm`, `label-lg`, `label-md`, `label-sm`; rounded `none`, `sm`, `md`, `lg`, `xl`, `full`.

### The sections

Eight canonical `##` headings, in this order. Out-of-order sections trip `section-order`; a **duplicate heading is a hard error that rejects the file**.

| # | Section | Alias | Carries |
|---|---------|-------|---------|
| 1 | Overview | Brand & Style | the visual intent, in prose |
| 2 | Colors | none | palette rationale; `colors` tokens |
| 3 | Typography | none | the type hierarchy; `typography` tokens |
| 4 | Layout | Layout & Spacing | grid, whitespace; `spacing` tokens |
| 5 | Elevation & Depth | Elevation | shadow and surface hierarchy |
| 6 | Shapes | none | corner language; `rounded` tokens |
| 7 | Components | none | component guidance; `components` tokens |
| 8 | Do's and Don'ts | none | guardrails, anti-patterns, **and UI copy voice** |

Two further sections are permitted **after** Do's and Don'ts, because the spec preserves unknown headings without error: **`## Motion`** and **`## Dark Mode`**. Both are prose only, and the reason below is not a stylistic preference.

Voice belongs in Do's and Don'ts rather than a section of its own. Rules about the strings on screen ("errors name the fix, not the failure") are guardrails, and the spec already has a section for guardrails.

### What never goes in YAML

Verified by running the linter, not inferred from the docs. Two shapes look reasonable and both produce warnings on a file you'd otherwise call clean:

| Tempting | What the linter does | Do this instead |
|---|---|---|
| A top-level `motion:` token map | ⚠️ `token-like-ignored`, *"looks like a design-token map but is not a recognized schema key … will be silently ignored by export commands"* | prose in `## Motion` |
| `transitionDuration:` on a component | ⚠️ `broken-ref`, *"not a recognized component sub-token"* | prose in `## Motion` |

**The complete set of valid component sub-tokens is `backgroundColor`, `textColor`, `typography`, `rounded`, `padding`, `size`, `height`, `width`.** There is no duration, no easing, no border, no gap. Anything else warns.

So **motion has no token home anywhere in the schema.** Durations and easing curves are prose, and that's the honest representation until the spec grows a place for them.

What *is* token-legal is **interaction state**, through the related-key pattern the spec defines: `button-primary`, `button-primary-hover`, `button-primary-active`. Extract those as real component entries. Never invent a custom key to hold a state the pattern already expresses.

### The stamp

Every file designkit writes ends with one visible line, after the last section:

```markdown
_Extracted from `main`@`a1b2c3d` on 2026-08-06._
```

Both halves earn their place: [`audit`](#mode-audit) recovers the baseline with `git show <sha>:DESIGN.md` while the SHA is reachable, and falls back to the date once a squash-merge has orphaned it. An HTML comment would be invisible in every renderer, which is exactly how a stale file comes to read as current.

A file with **no** stamp was written by a human. Adopt it, work with it, never silently claim it, and say plainly that you're editing a file designkit didn't author.

## The CLI is the source of truth

The format is at version `alpha` and openly under active development. Hardcoding the schema into a skill is how the skill becomes confidently wrong, so **read the spec at run time** and treat the summary above as a dated fallback:

| Command | Use |
|---|---|
| `npx @google/design.md spec [--rules] [--format json]` | the current schema and rule set |
| `npx @google/design.md lint <file> [--format json]` | validate; JSON by default |
| `npx @google/design.md diff <before> <after>` | compare two versions |
| `npx @google/design.md export --format {json-tailwind\|css-tailwind\|dtcg} <file>` | emit tokens |

Exit codes: `0` success, `1` errors or regressions, `2` file read failure. On Windows PowerShell use the `designmd` alias, because the `.md` file association hijacks the other form.

The eleven lint rules run on every file: `broken-ref` (error), `contrast-ratio`, `orphaned-tokens`, `missing-primary`, `missing-typography`, `section-order`, `unknown-key`, `token-like-ignored` (warnings), and `token-summary`, `missing-sections`, `omitted-rules` (info). **`contrast-ratio` already enforces WCAG AA at 4.5:1**, so never write your own contrast math.

## The extraction engine

One engine, shared by `init`, `update`, and `audit`. `init` writes its output, `update` diffs and applies it, `audit` diffs and reports it. `audit` skips [Show the work](#show-the-work), the engine's only write. There is no manifest of watched paths to maintain, and therefore no change that goes unnoticed because a glob failed to cover it.

### Find the token home

First rung that matches, and **say which one matched before writing anything**:

| # | Rung | Looks like |
|---|---|---|
| 1 | Tailwind | `@theme` in CSS (v4), or `tailwind.config.*` `theme.extend` (v3) |
| 2 | CSS custom properties | a `:root` block of `--token: value` |
| 3 | Preprocessor variables | SCSS `$vars`, Less `@vars`, a map file |
| 4 | CSS-in-JS theme | a theme object passed to a provider |
| 5 | WordPress | `theme.json` `settings.color.palette`, `settings.typography` |
| 6 | **Nothing** | no declared tokens anywhere; see [when there's no system](#when-theres-no-system) |

### Derive from usage, not declarations

A declared token nobody uses is not the design system; forty hardcoded hexes are. Read both:

- every color literal in stylesheets, templates, and components, meaning hex, `rgb()`, `hsl()`, `oklch()`, and named colors
- the font sizes, weights, and line heights actually applied
- the padding, margin, and gap values that recur
- corner radii and shadows in use
- the interaction states actually styled: `:hover`, `:focus-visible`, `:active`, `disabled`, and their framework equivalents
- dark mode: grep `.dark`, `prefers-color-scheme`, `dark:` variants, `[data-theme]`

Count occurrences. A value used ninety times and a value used once are not equally part of the system, and the counts are what make the next part defensible.

### Classify every token

Each token carries one of three states, and the classification is shown at the consent gate:

| State | Means |
|---|---|
| `extracted` | the value appears in the code as-is, used enough to be systematic |
| `consolidated` | clustered from N near-duplicates; **list them**, so the merge is reviewable and reversible |
| `omitted` | not derivable from the code; goes in the spec's native `omitted` field, never invented |
| `supplied` | given by the user in `init`'s interview, in a repo with no UI to extract from |

**`omitted` is a feature, not a failure.** The field exists precisely to declare deliberate exclusions and to suppress missing-section warnings. A DESIGN.md that honestly omits elevation beats one that invents a shadow scale.

### When there's no system

The likeliest real input: hundreds of hardcoded values, no token home, no consistency. designkit **clusters and proposes**. It does not refuse, and it does not fall through to an interview when the taste is already on screen, just messily.

The proposal is bound by the grounding rule: **every proposed token is a value that occurs in the code.** Cluster near-duplicates, choose the most-used member of each cluster as the representative, and list the members it absorbs. Never emit a value the codebase has never contained.

Tune the cluster threshold to the project and **state the threshold you used**, because it's a judgment call, and an unstated one is unreviewable. Perceptual distance for color, nearest-step for spacing and type. When a cluster is too loose to call one system, split it rather than forcing a merge, and say so.

### Show the work

This step runs in `init`, and in `update` only when a gated change needs review. `audit` skips it, because it writes a file.

Before writing anything, emit a **disposable swatch sheet**: a plain HTML page of color chips, type specimens, spacing bars, and radii, each labelled with its token name, its state, and the values it absorbed. Reviewing "forty greys became six" as a YAML diff is not realistic; as swatches it takes seconds.

This is **review scaffolding, not a deliverable.** Write it to a gitignored scratch path, add that path to `.gitignore` if it isn't covered, name it in the consent ask, and don't keep it. It is emphatically not the generated UI this skill refuses to write; it's a proof sheet for a decision.

## Mode: `init`

### 1. Ground it

Run [the extraction engine](#the-extraction-engine). Name the rung that matched, the number of distinct values found per category, and the dark-mode verdict, before proposing anything. This step is done when every category (color, type, spacing, radius, shadow, state, dark mode) has a count or a "none found".

### 2. Interview only when there's nothing to read

No UI in the repo means nothing to extract. Ask for the essentials (brand intent, an existing palette, type preferences). Every value the user gives becomes a `supplied` token; designkit adds no value of its own. Say plainly in the report and in the file's Overview that the result is **proposed, not extracted**. Anything still unknown is `omitted`. Skip this step when the engine found UI. This step is done when every schema category holds `supplied` tokens or is `omitted`.

### 3. Propose, and gate on it

Show the swatch sheet plus the `extracted` / `consolidated` / `omitted` breakdown, the cluster threshold, and every inconsistency found. **This is the gate that matters**, because the user accepts, trims, or redirects before a file exists. This step is done when the user accepts the proposal, with or without trims.

### 4. Write, stamp, validate

Write `DESIGN.md` at the repo root, append the stamp, then run `lint` and report its findings verbatim, including any that remain. A warning you chose to accept is reported as accepted, never suppressed. This step is done when `lint` exits `0`, or every remaining finding is reported, or the lint gap is named.

### 5. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Report the file created, the rung that matched, how many tokens landed in each state, and what was omitted.

**Where it landed.** Give `DESIGN.md` at the repo root, the swatch sheet's scratch path (and that it's disposable), and the lint result.

**Next.** Read the file. It's a claim about your project's visual identity and it's the one thing here a human should actually check. Then commit it with **commitkit** when installed, otherwise `git add DESIGN.md` and commit. If the project has a token home and the file's values differ from it, [`sync`](#mode-sync) is the follow-up; if it doesn't, there is nothing to sync and no next step to invent.

## Mode: `update`

### 1. Resolve the target

Uncommitted working-tree changes first (`git status --porcelain` non-empty → `git diff HEAD`, plus untracked files, which `git diff` never shows). Otherwise the branch diff against the base ref, from **gitkit** when it's installed, else the repo's default branch via `gh repo view --json defaultBranchRef`. **Never assume `main`.** Say which target you chose in one line. The target scopes what `update` applies, in [Apply, with restraint](#3-apply-with-restraint). This step is done when the target line names the range and lists the changed UI files, untracked ones included.

### 2. Re-extract and diff

Run the engine against the current code and diff its result against the committed `DESIGN.md`. Where the stamped SHA is still reachable, also run `npx @google/design.md diff <baseline> <current>` for the structured token-level comparison. Re-extract the whole codebase, not only the target, so a usage count stays true. Then sort each drift: **in target** when its value occurs in a changed hunk or untracked file of the target, **outside target** otherwise. This step is done when every drift is sorted.

### 3. Apply, with restraint

A changed brand color edits the color token. It does not regenerate the file. **State which sections are affected and which are deliberately untouched before editing**, because the untouched list is the load-bearing half, and it's what shows the skill knew what it was leaving alone.

Edits to existing tokens and prose land directly when the drift is in target; they're bounded by that restraint and land in a reviewable diff. **New sections, deletions, and outside-target drift are consent-gated.** Outside-target drift is older than this change, so list it and apply it only on a yes; otherwise route it to `audit`. A skill that rewrites a design system because one button changed is worse than no skill. This step is done when every in-target drift is applied and every gated item has a verdict.

### 4. Re-stamp and validate

Re-stamp with the current ref and SHA, run `lint`, report. This step is done when the stamp names the current SHA and the lint result is reported.

### 5. Hand off

**What changed.** Report tokens edited (one line each, naming the value that moved), sections proposed and their verdict, outside-target drift and its verdict, and sections deliberately untouched.

**Where it landed.** Give `DESIGN.md`, and the lint result.

**Next.** Run **commitkit**, then **prkit** if this is branch work (otherwise `git commit` and `gh pr create`). The design system lands in the same commit as the UI change that moved it; that's the point of keeping it in the repo.

## Mode: `audit`

**Read-only. Writes nothing, ever.** It reports and routes; fixing is a separate invocation, deliberately.

Three checks:

- **Lint.** Run `npx @google/design.md lint`, findings reported as-is.
- **Drift.** The check only designkit can do, because the linter validates the file against *itself* and has no view of the codebase. Two directions: tokens in the file that no longer appear in the code, and values in the code that no token covers.
- **Baseline.** Run `npx @google/design.md diff` against `git show <stamped-sha>:DESIGN.md`, when the SHA is reachable. Write the baseline copy to the system temporary directory (`mktemp`), never into the repo.

Run the extraction engine without its swatch sheet. The audit is done when each of the three checks has a result or a named gap.

### The report

| Verdict | Means |
|---|---|
| `current` | the file's tokens match what the code uses |
| `stale` | a token's value has moved in the code |
| `orphaned` | a token in the file appears nowhere in the code |
| `uncovered` | a value used in the code that no token covers |
| `unverified` | a human-written file designkit has never checked |

Open with a coverage line, naming how many files were scanned and how many skipped, because an audit that silently covered a fraction of the UI reads exactly like a clean bill of health. Then crown one next move.

### Hand off

**What changed.** Nothing. Say it outright; a reader should never have to wonder whether a read-only mode wrote something.

**Where it landed.** Inline in this reply. There's no audit artifact by default; offer to save one only if asked.

**Next.** Crown the single worst drift and route it to [`update`](#mode-update), or to [`init`](#mode-init) when the file is missing rather than wrong. **"Nothing has drifted" is a valid, stated result**, so say the system is current and stop.

## Mode: `sync`

**On consent, and only where a token home already exists.** designkit never introduces a token system to a project that doesn't have one, because that's a build-tooling decision, not a documentation one. With no token home, say so and stop; there is nothing to sync.

### 1. Find the home and the gap

Run the engine's [Find the token home](#find-the-token-home) and name the rung. Compare each `DESIGN.md` token with the home's value. This step is done when every token is marked same, different, or absent from the home.

### 2. Export and write, on consent

Show the token changes the write would make, and ask once. On a yes, write by the table below:

| Token home | How |
|---|---|
| Tailwind | the official `export --format json-tailwind` or `css-tailwind` |
| Plain `:root` custom properties | written directly, since `css-tailwind` emits a v4 `@theme` block *of custom properties*, so this is transcription, not conversion |
| SCSS maps, CSS-in-JS, WordPress `theme.json` | `export --format dtcg`, then route to a translator such as Style Dictionary |

The seam is **transformation, not framework**: if the official exporter already emits the shape, designkit writes it; if it needs real conversion, designkit emits DTCG and names the tool. Hand-rolled converters drift the moment either format moves.

This step is done when every different or absent token is written, or exported as DTCG with the translator named, or the user declined.

### 3. Hand off

**What changed.** Report the token home written, one line per token that moved, or that the user declined.

**Where it landed.** Give the token home path, or the DTCG export path and the translator to run.

**Next.** Commit the token home and `DESIGN.md` together with **commitkit** when installed, otherwise `git commit`.

## Degrade loudly

No `npx`, no network, or no CLI is a normal condition, not an error. Extract and write from the fallback schema above, skip lint and export, and **name the gap in the same breath as the result**:

> Wrote `DESIGN.md` (12 colors, 6 type styles). `lint` not run, because no `npx` was available. Schema from the bundled `alpha` fallback captured 2026-08-06.

Never claim validation that didn't happen. A file reported as clean when nothing checked it is worse than a file reported as unchecked.

No filesystem at all (a browser-based agent)? Print the finished `DESIGN.md` as a fenced block labelled with its path, describe the swatch sheet rather than writing it, and name the commands the user should run themselves.

## Notes

- **The grounding rule outranks completeness.** A sparse, honest file beats a full, invented one. When the choice is between omitting a scale and guessing at it, omit and say so.
- **Consent by operation.** The per-mode table in [When this fires](#when-this-fires) is the source. In-target edits to existing tokens in `update` don't ask, because they're bounded by the restraint rule and land in a reviewable diff. `audit` asks for nothing, because it changes nothing.
- **Report warnings, never suppress them.** If a lint warning survives, it goes in the report with the reason it was accepted.
- **Existing project convention wins.** A repo with its own token names, its own file location, or its own design-doc layout gets followed, and designkit says which convention it followed.
- **The spec is alpha.** Sections, schema keys, and rules move. Read them from the CLI at run time; when the bundled fallback is what ran, say so.
- **Prose is for rationale, tokens are for values.** An agent needs the hex, not the story behind the hex. Keep prose to what a token can't carry: intent, and when *not* to reach for something. For a general pass over that prose, use **humankit** when installed.
