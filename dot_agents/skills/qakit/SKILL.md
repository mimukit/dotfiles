---
name: qakit
description: >-
  Generate a QA plan for a feature just implemented, grounded in the actual code changes: the agent runs every check with an observable result, in a headless browser when one is available, and leaves a short manual list of what needs human judgment, saved to docs/qa. Use when a coding session wraps and you want to hand-test the result, or the user says "write a QA plan", "make a manual test plan", "how do I test this", "generate a testing plan for this feature", "try to break this component", or runs /qakit.
license: MIT
allowed-tools: Read, Bash, Write
metadata:
  internal: false
---

# qakit

Turn a feature an AI agent just implemented into a **QA plan**: the agent runs every check it can and records the results, and a short manual half with concrete steps, inline checkpoints, and pass/fail/skip boxes is left for a person. Both halves are grounded in what the code actually changed rather than a generic checklist. The plan is written to `docs/qa/` so a person can walk the manual half top to bottom and sign off on the feature.

The human's part is **judgment**: does the screen look right, does it match the mockup, does the flow feel good, does the copy read well. Everything else is the agent's. The value is a disciplined, diff-grounded plan whose manual half is short because nothing a machine can confirm reaches it.

Anything with an **observable pass condition** does **not** belong in the human's checklist: a command's output, an endpoint's response, a return value, and, when a browser driver is available, what a page shows (a figure reads `7`, a click lands on `/account/orders/`, the search field is absent, nothing overflows at 375 px). The agent runs those itself and reports the results in an **Automated verification** section at the end of the plan, so the human sees them confirmed without re-running them by hand. The agent also captures a screenshot of every screen the human must judge and builds one gallery page that groups them by case, so most of the manual pass is looking at images.

The plan is organized around **setup**, not around dimensions. Setup is what a manual QA pass actually costs: reseeding data, logging in, getting the app into a particular state. A plan that makes the tester rebuild the same state five times because five cases each restate it is a worse plan than one with fewer, fatter cases.

## When this fires

The user finishes building something and wants to verify it by hand: "write a QA plan", "manual test plan", "how do I test this feature", "give me a testing checklist", "/qakit", or a bare "QA this" after a coding session. qakit produces a plan whose manual cases a **human** runs. It writes no test code. It runs the project's existing test, lint, and build commands and drives the running app in a browser only as agent-verifiable checks, so the human never repeats a check a machine can confirm (see [Run the automated checks yourself](#5-run-the-automated-checks-yourself)). If the user wants *new automated* tests (unit, integration, E2E), say so and stop without a manual plan: tests for new work belong to **implementkit** in TDD mode, and a codebase with no tests at all belongs to **testkit**. Without those kits, name the plain step: write the tests beside the change.

## Procedure

### 1. Scope the feature
Ground the plan in what was actually built, because a generic plan is worthless. Gather, in order of preference:

- **The session context**, meaning what the user asked for and what you implemented this session. When you built the feature yourself, this is your best source and it costs nothing: you know its entry points and its failure modes better than the diff shows them.
- **The change**, when a repo is present: `git diff --stat HEAD` and `git log --oneline -10` to see which files and commits are in scope. A QA plan is written at the level of *behavior* (endpoints, screens, flags, commands, states) rather than lines, so read full diffs only for the files that carry behavior you can't already name: a route or handler, a form, a CLI entry point, a migration, a config default. Skip lockfiles, build output, and vendored directories entirely, and don't read a full diff for a file whose behavior the session already told you about.
- **The user**, only if intent is still unclear. Ask what the feature is *supposed* to do and how they normally exercise it (URL, command, screen, credentials), in one focused question, not an interview.

Write down, for yourself: the feature's intended behavior, its entry points, and its dependencies (services, data, auth, config). Everything downstream hangs off this.

Record the revision under test, too: `git rev-parse HEAD` and whether `git status --porcelain` is empty. The plan's header stamp and every reused check result bind to this pair.

Diff touches the data layer (a migration, a schema file, a model, or a query) → read [db.md](db.md), then follow it in every step it names.

Change renders data in a UI and a driver is present, or the user asks to try to break a component → read [worst.md](worst.md), then follow it in every step it names.

When the change has a UI, list the **browser drivers** in order of preference: a CLI driver on `PATH` that opens a URL, clicks, reads the page, and writes a screenshot (probe `command -v playwright-cli`), then each browser-automation MCP tool set in this session (a host's own preview browser counts). [Run the automated checks yourself](#5-run-the-automated-checks-yourself) starts the first one and moves down the list when it fails. No driver means the page checks stay with the human, as [Derive the test dimensions](#2-derive-the-test-dimensions) describes. Do not install one; verifykit `setup` does that when it is installed. Read the viewport widths from the project's `DESIGN.md` breakpoints when it has them; otherwise use 1440 px and 375 px.

Find the **disposable target**, if the project declares one: an environment that a documented command destroys and rebuilds, such as a playground app or a local database container, named as throwaway in the project's agent instruction file or README, together with its reset command. A declared target makes state-changing commands agent-verifiable on that target only. Never infer one: a local database that nobody declared throwaway may hold someone's work.

This step is done when intended behavior, every entry point, every dependency, and the revision pair are written down, and you know whether db.md and worst.md apply, which browser drivers you have, and which disposable target the project declares, if any.

### 2. Derive the test dimensions
Walk every dimension below and generate candidate cases for each one that applies to the feature. Skip a dimension only when it's genuinely irrelevant, and say so under *Not covered* in the plan so the tester knows it was considered, not forgotten:

- **Happy path.** The feature used exactly as intended, the primary flow end to end.
- **Edge & boundary.** Empty input, max/min values, off-by-one boundaries, unusual-but-valid states, duplicates, unicode/large payloads. When worst.md applies, it adds the worst-case values for every rendered field.
- **Negative / error handling.** Bad input, missing/expired auth, unavailable dependencies, network failures; assert it fails *gracefully* with a clear message and no corruption.
- **Regression.** Nearby behavior the change could have broken (shared components, the prior flow, adjacent features).
- **Security & permissions.** Role/ownership checks, access to another user's data, injection-style input, secrets not leaked in logs or responses.
- **Data & state.** Persistence after reload/restart, idempotency, correct create/update/delete, no orphaned or stale state. When the diff touches the data layer, db.md adds the database assertions. When it touches none, skip the database half and say so under *Not covered*, exactly like any other dimension.
- **Concurrency & timing.** Simultaneous actions, double-submit, race conditions, retries, slow responses.
- **Compatibility.** Where there's a UI: target browsers/OS/devices, responsive/mobile layout, dark mode.
- **Accessibility.** Keyboard navigation, focus order, screen-reader labels, and contrast, where there's a UI.
- **Performance.** Responsiveness under realistic or large data volumes; no obvious slowdown or leak.
- **Usability / UX.** The feel a human must judge: clear copy, sensible defaults, discoverable actions, helpful empty/loading states.

Prioritize: tag each case with one of three tiers, each carrying an emoji so the tester reads urgency at a glance:

- 🔴 **Critical.** Must pass to ship; a failure blocks release.
- 🟡 **Normal.** Should pass; a failure is a real bug but not a blocker.
- 🟢 **Low.** Nice-to-have, polish, or edge cases with minor impact.

Don't pad, because one clear check per behavior beats ten redundant ones. Scale the count to the feature's surface area and risk. What you have at the end of this step is a flat pile of candidate cases; the next step decides which of them are actually separate cases.

**Split human-only from agent-verifiable.** As you generate cases, sort each checkpoint with one test: *can you write its pass condition as an assertion a script evaluates?* If yes, it is agent-verifiable. That covers command output, HTTP responses, return values, and, with a browser driver, everything a page exposes: text and figures, the URL after a click, an element present or absent, a link's `href` and `target`, a class or attribute such as the theme, keyboard focus order, an accessible name, console errors, and horizontal overflow at a given width. If no, it is human-only: the screen looks right, matches the mockup, reads well in dark mode, feels smooth, or the copy says the right thing. External effects the app cannot observe (a WhatsApp message arrives, a payment settles, an email lands) and anything that needs real credentials or a physical device also stay human-only. Without a browser driver, page checks are human-only too. A command that changes state (a setup, a migration, a drop, a reset) is agent-verifiable only on a declared disposable target; on anything else it stays with the human.

Only the human-only checkpoints reach the plan's test cases. Run the agent-verifiable ones yourself and record their outcomes in the **Automated verification** section. Never list a check with an observable pass condition as a manual step. A case often splits: its figures and links go to the agent, and "the layout matches the mockup" stays with the human. Expect a UI plan to keep roughly ten human checkpoints or fewer. When it keeps many more, apply the assertion test to each one again.

This step is done when every dimension has candidate cases or a *Not covered* line, and every candidate carries a tier and a human-only or agent-verifiable tag.

### 3. Group the cases into scenarios
A **scenario** is one setup, every case that can run on top of it, and one reset at the end. Sort the candidate cases by the starting state each one needs, then:

- **One scenario per distinct starting state.** Two cases that need the same state belong in the same scenario, always. The tester sets up once, runs the whole scenario, resets once.
- **Merge cases that share a setup *and* a flow.** If confirming three behaviors just means walking one flow and looking at three things along the way, that's *one* case with three checkpoints, not three cases that each restate the same six steps. Failure isolation comes from the checkpoint, not from the case: an unticked box points at exactly one behavior just as precisely as a failed case did, and costs the tester nothing to reach. **This is a merge, not a relocation**, so the merged case ends up with three checkpoints, not with every assertion the three cases spelled out between them, stacked into a column of boxes. The checkpoint rules in [Write the plan file](#4-write-the-plan-file) are what stop the squeeze from simply reappearing one level down.
- **Split only when the flows genuinely diverge**, meaning a different entry point, or a case that leaves state the following case can't tolerate.
- **Order within a scenario: read-only first, state-mutating next, destructive last.** A case that deletes the record every other case needs goes at the end, or earns its own scenario.
- **Fewest scenarios that still cover the dimensions.** A new scenario has to justify itself with a genuinely different starting state; "it feels like a different topic" doesn't.

Name a scenario for the state it starts from ("Fresh tenant, no data", "Existing user with 200 orders", "Feature flag off") rather than for its topic ("Validation", "Error handling"). The name is what tells the tester whether they're already in the right state.

Number cases within their scenario: `TC-<scenario>.<case>`, so `TC-2.3` is the third case of Scenario 2.

This step is done when every human-only candidate sits in exactly one scenario, and every scenario has a distinct starting state.

**Everything true for the whole plan is not scenario setup.** Branch, build, base URL, credentials, auth token, feature flags, and launch command go once in **Environment** at the top. Each scenario's **Setup** carries only what's specific to that scenario. This is the split that keeps setup connected to the cases that need it.

### 4. Write the plan file
Write to `docs/qa/NNNN-qa-<feature-slug>-YYYY-MM-DD.md`, using the next serial, a short lowercase kebab-case feature slug, and the plan's ISO creation date (for example, `0012-qa-login-throttle-2026-07-23.md`). To get the serial `NNNN`, take the highest leading four-digit serial in `docs/qa/` across this worktree, every other worktree that `git worktree list` names, and `origin/HEAD` (`git ls-tree --name-only origin/HEAD docs/qa/` after `git fetch origin`), and add one; start at `0001` when there is none. Scan all three, because parallel worktrees otherwise take the same serial. Skip a source that fails, such as no remote, and without git list the directory only. The serial is per directory and never reused. Keep the whole name stable on later edits; record an updated date inside the document when useful. Create `docs/qa/` if it doesn't exist. Update an existing QA plan for the same artifact in place, and keep its name even when it has no serial.

Structure the file like this (the outer fence below is shown with four backticks only so the inner ```sh blocks display; the real file uses normal triple-backtick fences):

````markdown
# QA Plan: <Feature name>

_Generated <date> · against `<commit sha>` (<clean or uncommitted changes>) · covers <brief scope>_

## Summary
- What the feature does, in one short sentence.
- What "working" means, in one short sentence.

## Environment
True for the whole plan. Do this once, before Scenario 1.

- Branch / build under test
- Base URL, credentials, and how to obtain any auth token the calls need
- Feature flags / config
- Screenshots: local to this run at `<commit sha>` and not committed. The names under each case match the labels in the gallery.

Launch with:

```sh
<launch command>
```

- [ ] Environment ready

## Test cases at a glance

Priority legend: 🔴 Critical · 🟡 Normal · 🟢 Low

| # | Scenario | Test case | Priority |
|------|----------|-----------|----------|
| TC-1.1 | 1: <starting state> | <short title> | 🔴 Critical |
| TC-1.2 | 1: <starting state> | <short title> | 🟡 Normal |
| TC-2.1 | 2: <starting state> | <short title> | 🟢 Low |

## Scenario 1: <starting state>

**Setup.** Run once, for every case in this scenario.

1. <setup action>

```sh
<setup command>
```

- [ ] Setup complete

### TC-1.1: <short title>  ·  🔴 Critical

**Goal.** <one line: what this case proves>

**Steps**

1. <concrete action a human takes>
   - [ ] <one judgment the tester stops to make right here>
     - <what to look at, when the judgment needs a guide; a plain bullet, not a checkbox>
     - <another thing taken in at the same glance>
     - screenshots: `<screen>-light-1440` · `<screen>-dark-1440` · `<screen>-light-375`
   - [ ] <a second judgment, only when it's a genuinely separate look>
2. <next action; a command goes in its own block>

   ```sh
   <command to run>
   ```

   - [ ] <what the output or screen must show>

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _what actually happened on a fail; why it was skipped_

### TC-1.2: <short title>  ·  🟡 Normal
...

**Reset.** Run after every case above, before moving to Scenario 2.

```sh
<reset command>
```

## Scenario 2: <starting state>
...

## Automated verification (by AI agent)
_Checks the agent ran itself. No action needed from the tester; listed here for context and sign-off._

Commands run (one per block; chain with `&&` when they must run together):

```sh
<command 1>
```

```sh
<command 2>
```

- ✅ <command 1> → <what the output confirmed>
- ✅ <endpoint / assertion checked> → <result>
- ❌ <anything that failed, with the actual output> _(if any)_

### Browser checks
_Driven with `<driver>` against `<base URL>` at `<revision>`. <n> screenshots, local to this run and not committed._

- ✅ <page> · <what was asserted> → <the observed value>
- ❌ <page> · <what was asserted> → <the observed value, and what was expected>

## Not covered / needs human judgment
- <anything that can't be scripted: visual polish, UX feel, external integrations, timing>
- <dimension deliberately skipped, and why>

## Overall result
_Tick one when you finish the run, or skip the ticks. Report each failure in the agent session or as a PR comment, and the agent records it here._

- [ ] Pass: every case passed
- [ ] Fail: at least one case failed
- [ ] Partial: cases were skipped or not reached
````

Rules for good cases:
- **Never ask the tester to transcribe something you already know.** The header stamp carries the date and the exact commit the plan was written against, so fill both in yourself from `git log` and don't leave a blank table for a human to copy a sha into. The only thing the plan asks of the tester is the one judgment a machine can't make: the overall verdict. If they end up running against a different build than the stamp, that belongs in a case's **Notes**, not in a field every plan carries empty forever.
- **Overall result goes last, at the foot of the file.** The tester ticks it when the run ends, and the run ends at the bottom of the plan. A verdict box near the top asks them to scroll back through every case they just finished, so it stays unticked.
- **Fixed case body, always these four parts in this order:** **Goal**, **Steps**, **Result**, **Notes**. No case drops one, no case invents a fifth. A tester should be able to jump to any case in any plan and find the same shape.
- **Goal is one line and says what the case *proves***, not what it does: "an expired token can't reach another tenant's orders", not "test the orders endpoint".
- **Verification lives under the step that produces it.** Never a separate expected-results list at the bottom of the case: a step is followed immediately by its own `- [ ]` checkpoints, so the tester ticks as they go instead of holding five expectations in their head and reconciling them at the end. A step with nothing to observe simply has no checkpoints.
- **One checkpoint per *judgment*, not per assertion.** A checkpoint is one thing the tester stops to decide, not one fact the feature asserts. The test to apply: *would they plausibly tick one box and leave the next one unticked?* If they'd settle both in the same glance, it is one checkpoint. Granularity past the tester's attention doesn't buy precision, it fabricates it: nobody makes seven independent judgments while scrolling a page once, so seven boxes come back rubber-stamped and are then read as seven confirmations they never were.
- **Split different judgments; join one judgment applied across a set.** "The footer's headings, links, separator rule and copyright are all legible" is a single look at a single region, so one box. "The icon changed to the moon" and "storage now holds `dark`" are two places to look, so two boxes. The word "and" is not the test; whether the tester's eye has to move is.
- **Detail belongs *under* a checkpoint, as a plain unticked sub-list.** What to look at is worth spelling out, because it's the difference between "check the page" and knowing the pricing table's featured plan is the thing most likely to vanish. It just isn't worth a tick each:

  ```markdown
  1. Set the state to `light`. Scroll the whole page top to bottom at ≥1280px.
     - [ ] Every block reads correctly, with nothing illegible and nothing invisible on its own background
       - navbar: sticky background opaque; logo, links and control legible
       - hero: heading, sub-copy, both buttons; primary label against the primary fill
       - pricing-table: the toggle in both positions; the featured plan distinguishable; check marks
       - footer: headings, links, separator rule, copyright
  ```

  Failure isolation survives the collapse, because **Notes** already exists and a failing checkpoint needs a note regardless. That asymmetry is the goal: a plan that is cheap to run when it passes and only gets expensive where it fails.
- **A repeated pass gets one checkpoint plus whatever is new.** When a second variant re-runs a sweep the tester already performed (the other palette, the second browser, the next breakpoint, the swapped preset) never enumerate the same items again. **Never write "as above, in `<variant>`".** A line that carries no observation of its own is a loop counter the human ticks by hand:

  ```markdown
  2. Set the state to `dark`. Scroll the page again.
     - [ ] The same sweep is clean in dark
     - [ ] Nothing is pure-black-on-dark where a muted token was intended
  ```
- **Every checkbox owns its own line.** A `- [ ]` renders as a *clickable* checkbox only when it starts a line: write `[ ] Pass  [ ] Fail` inline and every previewer shows dead literal text the tester has to edit by hand. This applies to Result's three outcomes, each step checkpoint, and the Environment and Setup boxes alike: one per line, no exceptions, never side by side to save vertical space.
- **Observable, not internal.** Write what the tester sees or measures, not state they have no way to inspect.
- **Point each visual judgment at its screenshots by name, never by path.** A checkpoint about how a screen looks carries a plain `screenshots:` sub-bullet that names each capture [Run the automated checks yourself](#5-run-the-automated-checks-yourself) took for it, one name per variant, each in backticks and written in full. A name is `<screen>-<light|dark>-<width>`, the file name without `.png`, and it is the label the gallery shows. A path works on one machine only, breaks on GitHub and in every other clone, and says nothing about the commit it shows, so the committed plan carries names and the Environment line names the commit. The tester judges most screens from the gallery and opens the app only for motion, feel, and real interaction. Leave the sub-bullet out when no driver ran.
- **A screenshot that must last goes through verifykit, not the plan.** The capture folder is local and temporary. When a reviewer needs an image after the run, **verifykit** `proof` publishes the chosen images to a hidden ref and **prkit** embeds them in the PR body. Without verifykit, attach the image to the PR by hand.
- **Concrete and reproducible.** Real values and exact steps, so not "test the login" but "enter `bad@example.com` / blank password, click Sign in".
- **Skipped is a first-class outcome.** **Result** offers Pass, Fail *and* Skipped, one per line, and **Notes** carries the reason. A case the tester couldn't run, because the environment was missing, a dependency was down, or they ran out of time, has to be distinguishable from one nobody reached; a plan that comes back with silent blanks tells the next reader nothing.
- **Write the whole plan in the procedural register.** A tester reads it while doing something, often against a clock, so the plan is written in ASD-STE100 Simplified Technical English throughout: Goal, Setup, Reset, Steps, checkpoints and Not covered alike. One instruction per sentence. Procedural sentences 20 words or fewer, descriptive sentences 25 or fewer. Active voice, present tense, and name the actor ("the app redirects to `/login`", not "a redirect occurs"). Keep the articles. No metaphor, idiom, or word with a second meaning. Prefer short sentences and bullet sublists over paragraphs. **Pick one term per thing and keep it for the whole plan**, so if the setup calls it the *cart*, a later step does not call it the *basket*, and a checkpoint does not call it the *order*. This is the rule that costs the most attention and saves the most: a tester who has to work out that two words mean one thing stops trusting both. The rule is scoped to one plan; a different document may use different words.
- **Honest about gaps.** List what the plan can't verify under *Not covered*, including any dimension you deliberately skipped, rather than pretending coverage.
- **Every command gets its own ```sh code block.** Never inline a terminal command in prose or a table cell, and never stack multiple commands in one block, so the tester can copy each one with a single click of the previewer's copy button. When commands must run together, chain them with `&&` on one line inside a single block so one copy-paste runs the whole sequence.
- **Every API endpoint gets a runnable `curl`.** Whenever a case or check exercises an HTTP endpoint, include the exact `curl` invocation in its own ```sh block rather than describing the request in prose. Spell out the method, full URL (with the local base URL or a `$BASE_URL` that **Environment** defines), every required header, and a concrete JSON body with real sample values, copy-paste-ready, with no `<placeholders>` the tester has to guess at. Use `-i` (or `-s -w '\n%{http_code}\n'`) when a checkpoint covers a status code. This is the single biggest speedup in a QA pass: the tester runs the request instead of reconstructing it.

This step is done when the file exists at its serial path, every case has all four body parts, and every command and `curl` sits in its own block.

### 5. Run the automated checks yourself
Before handing off, actually run the agent-verifiable checks you split out in [Derive the test dimensions](#2-derive-the-test-dimensions), meaning terminal commands, endpoint hits, and return-value assertions, and record each outcome in the plan's **Automated verification** section (✅ passed with what the output confirmed, ❌ failed with the actual output). For anything you hit over HTTP, paste the **exact `curl` you ran** in its own ```sh block so the human can re-run or adapt it without rebuilding the request. This is the one part of the plan the agent completes, not the human. If there's no shell/filesystem, say so and leave the section for the human to fill.

**What you run, and why.** You run the project's own test, lint, and build commands as they already exist, the read-only checks db.md defines when it applies, and the browser checks below. These are the checks a machine can confirm, so running them keeps them off the human's list. You write no new test and edit no test file; a driven browser check lives in the plan, not in the test suite.

**One command class you never run, and one you reuse instead of re-running:**

- **Never: anything that destroys or rebuilds state**, such as `*:destroy`, `*:reset`, a teardown-and-rescaffold, a database write or drop, or a `clean` that wipes a build. This includes every scenario's own **Setup** and **Reset** block: those are written *for the human to run*, and the agent never executes them. Describe them; don't perform them. You are writing a plan *about* an environment, not administering one, and a QA agent that resets state can wipe the very build the human was about to test. The one exception is a declared disposable target, below.
- **Reuse: a gate already recorded green on this exact revision**, meaning a test, build, lint, or verify result that names the same HEAD sha and the same dirty state you recorded in [Scope the feature](#1-scope-the-feature). Record what it was, the revision it ran on, and that it passed; re-running it produces the same answer at full price, and it is the most common way this step becomes the most expensive one in a pipeline. A result that names no revision, or a different sha or dirty state, is not reusable: run the gate. Run it also when the change under test **is** that gate.

Both rules have the same shape: **inspect what exists, don't reproduce it.** If you need built artifacts to write good cases, read the ones that are already there.

**Scenarios on a disposable target.** When [Scope the feature](#1-scope-the-feature) found a declared disposable target, run each scenario whose Setup, steps, and Reset touch only that target yourself:

- **Say the target first.** State the target and its reset command in one line before the first command, so the operator can stop you.
- **Run the scenario as written.** Run Setup, then each case's commands in order, then Reset. Run nothing outside the target, and stop the scenario at the first command that would reach another host, another database, or a shared service.
- **Record the evidence in the case.** Tick each checkpoint you confirmed, tick the case's Result, and put the real output, trimmed to the lines that prove the checkpoint, in its **Notes**. Mark the scenario heading `· run by the agent on <target> at <revision>`.
- **Leave the target clean.** End with the declared reset command when the last scenario changed it, and record that run too.

These scenarios stay in the plan as cases, not in **Automated verification**, because their output is the record a reviewer reads. A command case whose target is not declared disposable stays manual.

**Browser checks.** With a browser driver from [Scope the feature](#1-scope-the-feature), drive the running app and record each page assertion under **Browser checks**. When worst.md applies, run its mock, reload, and assert loop on each screen in scope as well:

- **Reach the app.** Reuse a dev server that already serves the base URL. Otherwise start it once with the plan's launch command, and stop it when the checks end. Run no Setup, Reset, seed, or migration to reach a state, except on a declared disposable target. A check that needs one anywhere else stays a manual checkpoint.
- **Drive local state only.** A click that creates, deletes, submits, pays, or sends writes through the app. Drive it only against a local server with sample or demo data, or a declared disposable target. On any other host, the check stays manual.
- **Assert, then record the observed value.** "✅ `/account/` · Active orders card → `7`" proves more than "✅ figures correct". A ❌ records what the page showed and what the plan expected.
- **Capture the human's screens.** Take one screenshot of each screen a human-only checkpoint judges, in each variant the change supports: light and dark, and each viewport width from [Scope the feature](#1-scope-the-feature) for a responsive page. Save each one as `~/qakit/<plan file name without .md>/<screen>-<light|dark>-<width>.png`, never inside the repo, and write its name into its checkpoint. The folder is the run's own, and nothing in it is committed. When installed, **issuekit** `close` deletes it after the merge and **gitkit** `clean` sweeps old ones; otherwise delete it by hand once the PR merges.
- **Close the browser** when the checks end, because a CLI driver keeps a background browser alive between commands.

When a driver fails to start, record its error once under **Browser checks** and try the next driver on the list. When every driver fails, move the page checks back into the manual cases and name each error in the hand-off. Do not change the driver's sandbox or security settings to make it start; that is the operator's decision.

A ❌ is a defect the human no longer has to find. Do not fix it, because qakit writes no code. Put it first in the hand-off.

This step is done when every agent-verifiable check from [Derive the test dimensions](#2-derive-the-test-dimensions) has a ✅ or ❌ line, or a line that names the revision of the reused result, every scenario on a disposable target has its ticks and output and the target is reset, every human-only visual checkpoint has its screenshots or the plan says why not, and no browser or server you started is still running.

### 6. Build the gallery

Skip this step when no screenshot was captured, and say why in the hand-off.

The bundled [`gallery.py`](gallery.py) builds one page from the plan file, so the plan stays the single source. It reads each case, the checkpoints under its steps as the judge questions, and the `screenshots:` names, then groups the images in `~/qakit/<plan file name without .md>/` by case. Resolve the installed skill directory and run the script there; the working directory is the target project. Run plain `python3`, because `python3 -I` hides a Pillow installed for the user.

```sh
python3 "<path-to-this-skill>/gallery.py" docs/qa/<file> --dry-run
```

```sh
python3 "<path-to-this-skill>/gallery.py" docs/qa/<file>
```

```sh
python3 "<path-to-this-skill>/gallery.py" docs/qa/<file> --inline
```

- **Dry run first.** It prints each case with its judge questions and screenshot names, then the missing names and the "Other captures". A missing name is a typo in the plan or a capture that did not happen: fix the plan or take the capture, then run it again. An image in "Other captures" is one no checkpoint names: name it under its checkpoint, or leave it there as context.
- **`index.html` is the page to keep.** It is one self-contained file with every image embedded, and it opens in any browser.
- **`--inline` is for a host that renders HTML in the session.** It writes `inline.html` plus a `web/` folder of smaller copies that the page references by absolute path, styled with the host's theme variables. It warns when the page passes 512 KB. Build it only on such a host.
- **Pillow is optional.** With it, the script converts the images to WebP. Without it, `index.html` embeds the original PNGs, a larger file, and the script says so. Report that line in the hand-off.
- **The page names the capture commit** from the Environment line, and it shows a stale warning when `HEAD` has moved past that commit. A qakit refresh on the same plan builds the page again.

Without Python 3, skip the page and say so in the hand-off.

This step is done when the dry run shows no missing name and `index.html` exists, plus `inline.html` on a host that renders HTML, or the hand-off says why there is no gallery.

### 7. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Close with three short beats:

- **Failures first.** When a browser or automated check failed, list each ❌ with its observed value before anything else.
- **What changed.** Give a one-line summary: how many scenarios and manual checkpoints (and how many 🔴 critical), plus the automated and browser results (e.g. "2 scenarios, 7 manual checkpoints, 2 critical · 6 commands and 41 browser checks ran, 1 failed · Scenario 3 run by the agent on the playground, reset after"). Say that no manual case is marked. Tell the human to report failures in the session or as a PR comment; ticking the file is optional.
- **Where it landed.** Give the plan path, `docs/qa/<file>`, and the revision it was written against. Then show the gallery. When the host renders HTML in the session (T3 Code: `html_preview`, then `html_render` with the `contentHeight` the preview returns), render `inline.html` in the thread. Always give the path to `index.html` as well. Never hand off a bare screenshot folder.
- **Next.** With a ❌, fix it first with **implementkit** (otherwise fix it by hand), then run qakit again. With none, open the PR with **prkit** and hand it `docs/qa/<file>`, so the PR's test plan links the QA plan. Without prkit, run `gh pr create` and put the plan path in the body.

Don't mark any *manual* case as passed yourself, because those are the human's to execute. The agent fills the Automated verification section and the scenarios it ran on a disposable target, nothing else. Route to prkit; do not invoke it.

## Notes
- **Scope of shell use.** qakit runs the shell only to read the change and to run the project's own verification checks: `git diff`/`git log` to ground the plan, and the automated checks from [Run the automated checks yourself](#5-run-the-automated-checks-yourself) (the project's test, lint, and build commands, read-only database introspection on a local or confirmed host, and a browser driver against a local dev server), plus the bundled `gallery.py`, which writes only inside `~/qakit/`. Every command it runs is echoed in the plan's **Automated verification** section, so the user sees exactly what ran. It does not fetch remote code, touch credentials, or run anything destructive, and it reuses a gate result only when it names the same revision; see the two command rules in [Run the automated checks yourself](#5-run-the-automated-checks-yourself). If a verification step would modify state or need elevated access, describe it for the human instead of running it.
- **A plan, not a test suite.** qakit's output is a QA plan with its automated results filled in and its manual cases left for a human. It writes no unit, integration, or E2E tests; it runs the suite the project already has and drives the browser for this one plan.
- **A browser MCP and an HTML render tool are outside `allowed-tools`.** `Bash` covers a CLI driver such as `playwright-cli` and the bundled `gallery.py`. A browser MCP or a host's render tool arrives as tools whose names the server chooses, so a host that enforces `allowed-tools` strictly must grant them. Without the browser tools, qakit runs without a driver and leaves the page checks manual. Without the render tool, the hand-off gives the `index.html` path only. New automated tests belong to **implementkit** (TDD mode) for new work, or **testkit** for a codebase with no tests; when neither is installed, name the plain step rather than assuming a particular skill.
- **No filesystem or shell?** You can't write the file or read a diff. Instead ask the user to paste the change or describe the feature, then print the finished plan as a codeblock with the canonical `docs/qa/NNNN-qa-<feature-slug>-YYYY-MM-DD.md` path, with `0001` when you can't list their QA plans, for them to save themselves.
