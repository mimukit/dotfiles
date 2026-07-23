---
name: implementkit
description: >-
  Implement a plan, spec, or issue into working code — no commit, that's commitkit's job — picking straight-through vs TDD mode by precedence (prompt → CLAUDE.md → repo habit → ask), then running the repo's test + build/typecheck gate before declaring done. Use when the user says "implement this plan", "build this issue", "write the code for plan-<slug>-YYYY-MM-DD.md", "implement #42", "do this TDD", or hands off a hardened spec to be turned into code — even if they don't name a mode.
license: MIT
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
metadata:
  internal: false
---

# implementkit

Turn a hardened plan, spec, or issue into working code — and stop there. implementkit is the build step between a settled plan and a clean commit: it reads an explicit input, resolves *how* to build (straight-through or test-driven), writes the code, and proves it with the repo's own test and build gate before it calls the work done. It **never commits** — that's commitkit's job — and it **never designs** — an underspecified input is bounced back to plankit/grillkit, not guessed at.

Its defining feature is **mode resolution**: the same request builds differently depending on whether the repo (or the user) wants test-driven development, and implementkit works that out by a fixed precedence rather than defaulting blindly.

## When this fires

The user hands off something concrete to be built: "implement this plan", "build issue #42", "write the code for `docs/plans/plan-sso-2026-07-23.md`", "implement this spec", "do this the TDD way". It is the `implementkit` step of the plan → grill → file → **build** → commit workflow.

Two hard boundaries:

- **It does not commit or stage.** It leaves the finished work as unstaged changes and reports what it did; commitkit groups and commits.
- **It does not design.** If the input is too thin to build without inventing the design, it stops and points back to grillkit/plankit. implementkit turns a *settled* intent into code; it doesn't settle the intent.

## Procedure

### 1. Take an explicit input
Require the user to name what to build — a plan file (`docs/plans/plan-<slug>-YYYY-MM-DD.md`), an issue (`#42`, or a URL/id `gh` can fetch), or a freeform spec written in the prompt. Do **not** hunt for an input: if nothing is named, stop and ask what to implement. Read the named input in full (for an issue, fetch it with `gh issue view <n>`; if `gh` isn't available, ask the user to paste it).

### 2. Assess implementability, bounce if thin
Before writing anything, judge whether the input is concrete enough to build without inventing the design. A hardened plan or a fleshed-out issue passes. A bare title, a one-line ask, or a spec with unresolved core decisions does **not** — stop and tell the user to harden it first with grillkit (to interrogate the decisions) or plankit (to draft a proper plan), naming the specific gaps you hit. Don't paper over a thin spec with assumptions; a wrong guess here costs more than the bounce.

### 3. Resolve the mode
Pick **straight-through** or **TDD** by this precedence, taking the first tier that gives an answer:

1. **Prompt** — the user said so ("do this TDD", "just write it, no tests"). Explicit always wins.
2. **Agent instructions** — the repo's agent-guide file (`CLAUDE.md` or an equivalent) declares a mode or a test-first policy. Honor it.
3. **Repo habit** — infer from the codebase. Conclude **TDD only when both** are true: (a) real test infrastructure exists (a runner/config like jest, vitest, pytest, `go test`, rspec, cargo test), **and** (b) the repo actually ships tests with features — recent commits touch test and source files together, and the test-to-source ratio is healthy. Infra with no habit (a lonely config, tests that lag far behind the code) is **not** TDD.
4. **Ask once** — still unresolved and a user is there to answer? Ask a single time which mode to use. Non-interactive (a delegated/autonomous run with no one to answer)? Default to **straight-through** — TDD is the heavier mode and is never imposed silently. State which mode you resolved and why.

### 4. Build in the resolved mode

**Straight-through** — implement the production code to satisfy the input. Write **no new tests**; run the existing suite as part of the gate ([Run the done-gate](#5-run-the-done-gate)). Here the build/typecheck is the real safety net, since new code may be uncovered.

**TDD** — strict **red → green → refactor**, per unit of behavior:
1. **Red** — write one focused failing test for the next slice of behavior, **run it, and confirm it fails** (a test that passes before the code exists is testing nothing — fix it before continuing).
2. **Green** — write the minimal production code to make it pass; run it and confirm green.
3. **Refactor** — clean up code and test while the suite stays green.

Repeat per slice until the input is fully implemented. Match the surrounding code's conventions, naming, and structure in either mode — reuse what exists rather than reinventing it.

**Check as you go, not only at the end.** Keep the feedback loop tight while building: typecheck and run the **single** affected test file as each slice lands, so breakage surfaces where it's cheap to fix. Save the **full** suite and the build for the [done-gate](#5-run-the-done-gate). TDD's red→green already runs one test at a time; this closes the same gap in straight-through mode, which otherwise gets no signal until the end.

### 5. Run the done-gate
"Done" means the repo's checks are green, not just that code was written. Discover the commands from the repo itself (`package.json` scripts, `Makefile`, `pyproject.toml`, `justfile`, CI config) rather than guessing, and run:

- the **test** command, and
- the **build / typecheck** command (and **lint**, if the repo runs one).

All must pass before you declare done. If a command genuinely doesn't exist (no test script, no build step), say so and lean on what does exist — don't fabricate a command.

### 6. Fix on red, bounded
If the gate fails, try to fix your own output and re-run — but **bounded** to roughly three attempts. If it's still red after that, **stop**: never declare done on a failing gate, and never loop indefinitely. Report the failure, what you tried, and where you think it's stuck, and hand it back.

### 7. Hand off to commitkit
Leave every change **unstaged** — do not `git add`, do not commit, do not draft a commit message (that's commitkit's job, and pre-staging fights its grouping). Report a short summary:

- the **mode** used and which precedence tier decided it,
- the **files** created and changed,
- the **gate result** (which commands ran and that they passed).

Then point the user to commitkit when installed, or say plainly that the next step is to group and commit the changes. Don't run it yourself.

## Notes

- **Build only.** No commit, no staging, no PR — those are commitkit and prkit. implementkit's job ends at green, unstaged code.
- **Never guess the design.** Bouncing a thin input back to grillkit/plankit is a success, not a failure — it's the boundary that keeps this skill honest.
- **Never green-wash.** A declared "done" always means the gate actually passed. Red after the bounded fixes is reported as red.
- **Follow the repo over these defaults.** If the codebase has its own test/build commands, layout, or a stated workflow, follow that and say you did.
- No filesystem or shell (e.g. a browser-based agent)? Then you can't write files or run the gate — instead print the finished code as fenced blocks (one per file, with its path) for the user to save, note the mode you'd use, and list the gate commands they should run themselves.
