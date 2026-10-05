---
name: plankit
description: >-
  Turn a rough feature or change into a structured plan document (docs/plans/NNNN-plan-<slug>-YYYY-MM-DD.md) before any code: brainstorm the approach, settle the big decisions, and write a plan that can be hardened and turned into issues. Use when the user says "plan this feature" or "brainstorm a plan/PRD/spec", the front of the plan → grill → file workflow.
license: MIT
allowed-tools: Read, Grep, Glob, Write, Edit, AskUserQuestion
metadata:
  internal: false
---

# plankit

Turn a rough idea (a feature, a project, a spec, a PRD) into a structured plan document you can act on. plankit is generative: it brainstorms the approach, settles the decisions needed for a coherent draft, and writes a `NNNN-plan-<slug>-YYYY-MM-DD.md` grounded in the real codebase (not a guess). It is the front of a flow, **plankit drafts → grillkit hardens → issuekit files** where a project tracks work in GitHub Issues, and **plankit drafts → grillkit hardens → implementkit builds** where it doesn't. Either way the plan it writes is the exact input the next step expects. plankit **plans only**: it never writes application code and never creates issues.

## When this fires

The user wants to think a piece of work through *before* building it: "plan this feature", "brainstorm a plan / PRD / spec", "write a plan doc", "help me think through X first", "/plankit". One distinction matters:

- **It is not the adversarial interrogator.** That's grillkit. plankit asks enough to draft a coherent plan and records the thin spots as open questions; grillkit is what pressure-tests them one decision at a time.

## Procedure

### 1. Capture the idea
Get the concept, the problem it solves, who it's for, and the outcome that means success. If the input is a one-liner, ask a few **scoping** questions (use `AskUserQuestion` when available). Those are generative "what are we building and why", not adversarial "what did you miss". Ask one round at most, and only about the four items the input leaves open.

**Done when** the concept, the problem, the user, and the success outcome each have a one-line answer, from the input or from the user.

### 2. Ground it in reality
Research before proposing, so the plan reuses what exists instead of reinventing it.

- **In an existing repo:** read the relevant code, docs, and config to find the patterns, utilities, and conventions the plan should build on. Look up facts yourself (`Read`, `Grep`, `Glob`); reserve questions for genuine decisions. Never propose new code where a suitable implementation already exists; name the existing thing in the plan instead.
- **Greenfield (no repo yet):** skip the code research; ground the plan in the user's stated goals and constraints.

**Done when** every part of the system the work touches has its existing module, utility, or convention named by path, or is recorded as having none. In greenfield work, every stated goal and constraint is written down instead.

### 3. Diverge, explore approaches
Brainstorm the real options and **recommend one**, something concrete to accept or redirect, not a naked menu. This is the generative half: don't settle for the first idea, and consider the unconstrained version of the work before narrowing to the practical one.

When more than one credible path exists, default to a spread that is genuinely different rather than variants of one idea: a **minimal viable** (the smallest diff that ships and is useful), an **ideal** (the shape you'd choose with time to do it properly), and where one exists a **lateral** (a reframe that dissolves the problem instead of solving it). Name what each option **reuses** from the research above, so the plan stays anchored to the code you just read. Collapsing to a single approach is fine when the work warrants it, since "no credible alternative" beats an invented Option B.

**Done when** one approach is recommended, and each alternative either differs from it on a named axis or is replaced by a one-line reason that no credible alternative exists.

The failure mode is options that only *look* plural:

> **Variants (avoid):** cache the response · cache it with a shorter TTL · cache it behind a flag we can tune later. One idea in three hats, so there's no real choice to make.
>
> **Distinct (aim for):** cache the response (smallest diff, ships this week, goes stale on writes) · denormalize the read path so there's nothing to cache (a migration, but the whole staleness class disappears) · don't fix it here at all, because it's only slow when called in a loop, so batch upstream and the endpoint stops mattering.

### 4. Converge, settle the structure
Resolve the structural decisions a coherent draft needs (the architecture, the phases, the scope boundary) one at a time, each with a recommended answer. Then **stop**: deliberately leave the deeper, thin, or still-uncertain spots for grillkit rather than grinding every edge case here. Record those under **Open questions** in the doc so the hardening step has a target.

**Done when** the architecture, the phase list, and the scope boundary each have a settled answer the user accepted or redirected, and every other unsettled point sits in the Open questions list.

### 5. Write the plan document
Write `docs/plans/NNNN-plan-<slug>-YYYY-MM-DD.md`, where `NNNN` is the next four-digit serial in `docs/plans/`, `<slug>` is a short lowercase kebab-case name for the feature, and the suffix is the plan's ISO creation date (`0007-plan-sso-login-2026-07-23.md`). To get the serial, list `docs/plans/`, take the highest leading serial, and add one; start at `0001` when there is none. The serial is per directory and never reused, and it applies in every repo, a fresh one included. Keep the whole name stable on later edits; record an updated date inside the document when useful. Use the [plan-doc format](#plan-doc-format) below, which is the contract grillkit and issuekit both read, so keep the body phase/task-shaped. Create `docs/plans/` if it doesn't exist. If a plan for this work already exists, update it in place rather than writing a second file, and keep its name even when it has no serial. When that plan carries a `Grilled:` line and your update is [material](#when-a-grilled-stamp-goes-stale), delete the line and say so in the hand-off.

**Done when** the file exists at its path, every section in the format is filled or deliberately dropped, and every phase carries its acceptance observable.

### 6. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Report where the plan landed, and whether you removed a `Grilled:` line. Then offer the next step, in order, naming a sibling kit only when it is installed and otherwise describing the action in plain language:

- **grillkit.** Pressure-test and harden the draft (it can update this same file in place).
- **issuekit**, when the project tracks work in GitHub Issues. Turn the hardened plan into issues.
- **implementkit**, when it does not. Build straight from the plan, one phase at a time.

Name the second or the third, not both, when you can tell which applies. The prompt or the repo's agent-guide file says which; open issues on the repo are the weaker signal. Name both when nothing settles it, and never assume a project files GitHub issues just because it is hosted on GitHub.

If the planning surfaced project vocabulary worth pinning down or a hard-to-reverse trade-off decision, offer **domainkit** when installed; otherwise offer to record a glossary entry or ADR directly.

Do not start either yourself.

## Plan-doc format

The canonical structure plankit owns. Keep it lean, so every section earns its place, and keep the body organized as phases/tasks so issuekit can decompose it into issues:

```markdown
# Plan: <title>

## Context
The problem, why it matters now, and the outcome that means success.

## Design decisions (settled)
| Decision | Resolution |
|----------|-----------|
| <the choice> | <what we picked and, briefly, why> |

## Approach
The chosen approach and what it **reuses** from the existing codebase, then the plan body as phases/milestones/tasks, each a concrete, verifiable unit of work. This is the structure issuekit reads to propose an issue breakdown. When the alternatives were close, keep the rejected ones to a line each so the choice stays legible later.

### Phase 1: <name>
<the tasks>
Done when: <an observable a reviewer can check: a command and its output, a behavior in the running app, a test that passes>

## Migration and rollback
Only when the plan changes stored data (a schema, a persisted file format, existing records). How existing data moves to the new shape, in which phase, and how to undo it if the phase fails. Omit the section otherwise.

## Open questions
Unresolved or thin spots, written as targets for grillkit to interrogate.

## Non-goals
Explicit scope boundaries, meaning what this plan deliberately does not cover.
```

A hardened plan additionally carries a **`Grilled: YYYY-MM-DD` line directly under the title**. grillkit writes it when the plan survives a grill session, and issuekit reads it as the gate for filing issues `ready`. plankit never writes the stamp itself; a fresh draft is ungrilled by definition.

**Every phase ends on a `Done when:` line**, the acceptance observable. It names something a person or a test can check after the phase ships, never an intent ("auth works"). It gives the build a finish line to check against, and a phase without one has no finish.

### When a `Grilled:` stamp goes stale

The stamp vouches for the plan as it stood at the grill. A **material** edit is one that adds, removes, or changes a settled design decision; adds, removes, or re-scopes a phase; changes a `Done when:` observable; or changes the non-goals or the migration section. Whoever makes a material edit deletes the `Grilled:` line in the same edit, so the plan reads as ungrilled until grillkit runs again. Wording fixes, the phase-heading annotations below, an updated-date line, and new open questions are not material, and they leave the stamp in place.

### The phase-heading annotation slot

**A phase heading ends in an optional annotation, and downstream skills write into it.** plankit writes a bare heading (`### Phase 2: auth`) and never annotates one itself, because a fresh plan has neither been filed nor built. Two vocabularies share the slot:

- **`(#41)`**, written by issuekit when it files that phase as an issue. It says where the phase is tracked.
- **`(built YYYY-MM-DD)`**, written by implementkit when it finishes building that phase. It says the phase is done.

They coexist, so `### Phase 2: auth (#41) (built 2026-08-20)` is a tracked phase that shipped. Keeping both in one slot is what lets a reader and a survey tool answer "what is left in this plan?" from the plan alone, with no tracker to consult, which is the only way that question has an answer on a project that files no issues.

**The stamp is opt-in per plan.** A plan with no annotation anywhere makes no claim about itself, so nothing may read its phases as unbuilt. That is what lets the convention arrive without a migration: plans written before it stay silent and correct, and a plan starts making claims the first time something stamps it.

**Match the heading loosely.** A phase heading begins `Phase <n>` and the separator that follows varies across real plan sets, so anything reading these headings accepts a colon, a dash, or nothing.

## Notes

- **Plan only.** No application code, no issues; those are separate steps (implementkit, issuekit). plankit hands off; it doesn't cross into them.
- **Fewest honest sections.** Prefer a short, sharp plan over a padded one; drop a section rather than fill it with filler. Scale the doc to the work's real surface area.
- **Defer the grilling.** Leaving open questions is fine and expected. Draft a coherent plan and let grillkit harden it; don't try to be both.
- **Follow the repo's conventions.** If the codebase has its own plan/RFC/PRD location or template, follow that and say you did, rather than forcing `docs/plans`.
- No filesystem or shell (e.g. a browser-based agent)? Then you can't write the file. Instead print the finished plan document as a codeblock and give the user the canonical `NNNN-plan-<slug>-YYYY-MM-DD.md` filename, with `0001` when you can't list their plans, to save wherever they keep plans.
