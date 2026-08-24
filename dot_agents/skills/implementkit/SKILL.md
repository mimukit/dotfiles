---
name: implementkit
description: >-
  Implement a plan, spec, or issue into working code, picking straight-through vs TDD mode by precedence (prompt → CLAUDE.md → repo habit → ask), then running the repo's test + build gate before declaring done. Use when the user says "implement this plan", "implement #42", "do this TDD", or "apply these review findings". It stops before the commit and runs attended; the unattended issue-to-PR span is afkkit's.
license: MIT
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Skill
metadata:
  internal: false
---

# implementkit

Turn a hardened plan, spec, or issue into working code, and stop there. implementkit is the build step between a settled plan and a clean commit: it reads an explicit input, resolves *how* to build (straight-through or test-driven), writes the code, and proves it with the repo's own test and build gate before it calls the work done. It **never commits**, because that's commitkit's job, and it **never designs**, because an underspecified input is bounced back to plankit/grillkit, not guessed at.

Its defining feature is **mode resolution**: the same request builds differently depending on whether the repo (or the user) wants test-driven development, and implementkit works that out by a fixed precedence rather than defaulting blindly.

## When this fires

The user hands off something concrete to be built: "implement this plan", "build issue #42", "write the code for `docs/plans/plan-sso-2026-07-23.md`", "implement this spec", "do this the TDD way". It is the `implementkit` step of the plan → grill → file → **build** → commit workflow.

Two hard boundaries:

- **It does not commit or stage.** It leaves the finished work as unstaged changes and reports what it did; commitkit groups and commits.
- **It does not design.** If the input is too thin to build without inventing the design, it stops and points back to grillkit/plankit. implementkit turns a *settled* intent into code; it doesn't settle the intent.

## Procedure

### 1. Take an explicit input
Require the user to name what to build. The options are a plan file (`docs/plans/plan-<slug>-YYYY-MM-DD.md`), **optionally narrowed to one phase** ("implement phase 3 of `plan-sso-2026-07-23.md`"), an issue (`#42`, or a URL/id `gh` can fetch), a freeform spec written in the prompt, or a **fix round**: a concrete list of review findings (e.g. the blockers from a review pass), each naming what's wrong and where. Do **not** hunt for an input: if nothing is named, stop and ask what to implement. Read the named input in full (for an issue, fetch it with `gh issue view <n>`; if `gh` isn't available, ask the user to paste it).

### 2. Assess implementability, bounce if thin
Before writing anything, judge whether the input is concrete enough to build without inventing the design. A hardened plan or a fleshed-out issue passes. A bare title, a one-line ask, or a spec with unresolved core decisions does **not**. Stop and tell the user to harden it first with grillkit (to interrogate the decisions) or plankit (to draft a proper plan), naming the specific gaps you hit. Don't paper over a thin spec with assumptions; a wrong guess here costs more than the bounce.

**Thin for a different reason gets a different route.** When the input is unsettled because *nobody has seen the design work* (the state model looks fine on paper, the screen has never been laid out), no amount of interrogation settles it, because the missing input is evidence rather than a decision. That routes to prototypekit when it's installed, or to a deliberate throwaway spike otherwise; it comes back here once the question is answered.

A **fix round passes this bar by construction**, because the findings name the defects, so there is no design to invent; never bounce one as thin. It also skips mode resolution below: apply the named fixes directly in the style the surrounding code already shows, and let the done-gate prove them.

### 3. Resolve the mode
Pick **straight-through** or **TDD** by this precedence, taking the first tier that gives an answer:

1. **Prompt.** The user said so ("do this TDD", "just write it, no tests"). Explicit always wins.
2. **Agent instructions.** The repo's agent-guide file (`CLAUDE.md` or an equivalent) declares a mode or a test-first policy. Honor it.
3. **Repo habit.** Infer from the codebase. Conclude **TDD only when both** are true: (a) real test infrastructure exists (a runner/config like jest, vitest, pytest, `go test`, rspec, cargo test), **and** (b) the repo actually ships tests with features, so recent commits touch test and source files together, and the test-to-source ratio is healthy. Infra with no habit (a lonely config, tests that lag far behind the code) is **not** TDD.
4. **Ask once.** Still unresolved and a user is there to answer? Ask a single time which mode to use. Non-interactive (a delegated/autonomous run with no one to answer)? Default to **straight-through**, since TDD is the heavier mode and is never imposed silently. State which mode you resolved and why.

### 4. Build in the resolved mode

**Straight-through.** Implement the production code to satisfy the input. Write **no new tests**; run the existing suite as part of the gate ([Run the done-gate](#5-run-the-done-gate)). Here the build/typecheck is the real safety net, since new code may be uncovered.

**TDD.** Strict **red → green → refactor**, per unit of behavior:
1. **Red.** Write one focused failing test for the next slice of behavior, **run it, and confirm it fails** (a test that passes before the code exists is testing nothing, so fix it before continuing).
2. **Green.** Write the minimal production code to make it pass; run it and confirm green.
3. **Refactor.** Clean up code and test while the suite stays green.

Repeat per slice until the input is fully implemented. Match the surrounding code's conventions, naming, and structure in either mode, reusing what exists rather than reinventing it.

**Visual surfaces delegate.** When the work includes UI (a page, a component, a screen) and **uikit** is installed, apply it to those files instead of writing them blind; it carries the project's design constraint and runs its own visual pre-flight. Without it, write the UI directly. implementkit keeps everything else either way: the input contract, the mode resolved above, and the done-gate below, which remains the **only** gate.

**Check as you go, not only at the end.** Keep the feedback loop tight while building: typecheck and run the **single** affected test file as each slice lands, so breakage surfaces where it's cheap to fix. Save the **full** suite and the build for the [done-gate](#5-run-the-done-gate). TDD's red→green already runs one test at a time; this closes the same gap in straight-through mode, which otherwise gets no signal until the end.

### 5. Run the done-gate
"Done" means the repo's checks are green, not just that code was written. Discover the commands from the repo itself (`package.json` scripts, `Makefile`, `pyproject.toml`, `justfile`, CI config) rather than guessing, and run:

- the **test** command, and
- the **build / typecheck** command (and **lint**, if the repo runs one).

All must pass before you declare done. If a command genuinely doesn't exist (no test script, no build step), say so and lean on what does exist; don't fabricate a command.

### 6. Fix on red, bounded
If the gate fails, try to fix your own output and re-run, but stay **bounded** to roughly three attempts. If it's still red after that, **stop**: never declare done on a failing gate, and never loop indefinitely. Report the failure, what you tried, and where you think it's stuck, and hand it back.

### 7. Stamp the plan, when the input was one
Skip this step entirely unless the input was a plan file and the gate passed. Then mark what you built, so the plan says what is left.

Append `(built YYYY-MM-DD)` to the heading of each phase you finished, using today's date:

```markdown
### Phase 2: auth (built 2026-08-20)
### Phase 3: session refresh (#41) (built 2026-08-20)
```

Four rules keep the stamp honest:

- **Stamp only the phases you actually built.** A run narrowed to one phase stamps that phase and leaves every other heading untouched. Never stamp a phase you skipped, and never stamp the whole plan because most of it is done.
- **Stamp after the gate is green**, never before. The stamp is a claim that the work passed, so writing it on unproven code makes the plan lie about the exact thing it exists to record.
- **Keep an existing `(#41)` and add yours after it.** The two annotations coexist: the number says where the phase is tracked, the stamp says it is done.
- **Leave the edit unstaged**, like every other change in the run, so commitkit picks up the plan alongside the code that implements it.

Stamp on every run, whatever the project's tracker is. A project filing GitHub issues gets a plan that carries both annotations, and one filing none gets a plan that is its own work list. Deciding which kind of project this is would be a judgment implementkit does not need and should not make.

### 8. Hand off to commitkit

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Leave every change **unstaged**. Do not `git add`, do not commit, do not draft a commit message (that's commitkit's job, and pre-staging fights its grouping). Report a short summary:

- the **mode** used and which precedence tier decided it,
- the **files** created and changed,
- the **gate result** (which commands ran and that they passed),
- the **phases stamped**, and which phases of that plan are still unbuilt.

Then point the user to commitkit when installed, or say plainly that the next step is to group and commit the changes. Don't run it yourself.

Name the next phase of the plan when one is left. Say the plan is fully built when none is.

## Notes

- **Build only.** No commit, no staging, no PR; those are commitkit and prkit. implementkit's job ends at green, unstaged code.
- **`Skill` is here for the uikit delegation, and it is not free.** Invoking uikit on visual work pulls a large document into an already-large build context, and every later tool use in the run re-bills it. That is the trade: a UI surface built against the project's actual design constraint, with its own pre-flight, versus a cheaper run that writes the screen blind. Take it on UI work and nowhere else. implementkit invokes no other skill, and routing to commitkit at the end is naming a next move, not calling one.
- **Never guess the design.** Bouncing a thin input back to grillkit/plankit is a success, not a failure; it's the boundary that keeps this skill honest.
- **Never green-wash.** A declared "done" always means the gate actually passed. Red after the bounded fixes is reported as red.
- **Follow the repo over these defaults.** If the codebase has its own test/build commands, layout, or a stated workflow, follow that and say you did.
- No filesystem or shell (e.g. a browser-based agent)? Then you can't write files or run the gate. Instead print the finished code as fenced blocks (one per file, with its path) for the user to save, note the mode you'd use, and list the gate commands they should run themselves.
