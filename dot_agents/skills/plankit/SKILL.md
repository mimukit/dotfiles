---
name: plankit
description: >-
  Turn a rough feature or change into a structured plan document (docs/plans/plan-<slug>-YYYY-MM-DD.md) before any code — brainstorm the approach, settle the big decisions, and write a plan that can be hardened and turned into issues. Use when the user says "plan this feature", "brainstorm a plan/PRD/spec", "write a plan doc", "help me think through this change before building", or runs "/plankit" — the front of the plan → grill → file workflow.
license: MIT
allowed-tools: Read, Grep, Glob, Write, Edit, AskUserQuestion
metadata:
  internal: false
---

# plankit

Turn a rough idea — a feature, a project, a spec, a PRD — into a structured plan document you can act on. plankit is generative: it brainstorms the approach, settles the decisions needed for a coherent draft, and writes a `plan-<slug>-YYYY-MM-DD.md` grounded in the real codebase (not a guess). It is the front of a three-step flow — **plankit drafts → grillkit hardens → issuekit files** — so the plan it writes is the exact input those next steps expect. plankit **plans only**: it never writes application code and never creates issues.

## When this fires

The user wants to think a piece of work through *before* building it — "plan this feature", "brainstorm a plan / PRD / spec", "write a plan doc", "help me think through X first", "/plankit". One distinction matters:

- **It is not the adversarial interrogator** — that's grillkit. plankit asks enough to draft a coherent plan and records the thin spots as open questions; grillkit is what pressure-tests them one decision at a time.

## Procedure

### 1. Capture the idea
Get the concept, the problem it solves, who it's for, and the outcome that means success. If the input is a one-liner, ask a few **scoping** questions (use `AskUserQuestion` when available) — generative "what are we building and why", not adversarial "what did you miss". Enough to draft, no more.

### 2. Ground it in reality
Research before proposing, so the plan reuses what exists instead of reinventing it.

- **In an existing repo:** read the relevant code, docs, and config to find the patterns, utilities, and conventions the plan should build on. Look up facts yourself (`Read`, `Grep`, `Glob`); reserve questions for genuine decisions. Never propose new code where a suitable implementation already exists — name the existing thing in the plan instead.
- **Greenfield (no repo yet):** skip the code research; ground the plan in the user's stated goals and constraints.

### 3. Diverge — explore approaches
Brainstorm the real options. For a decision with more than one credible path, lay out the alternatives with their tradeoffs and **recommend one** — give the user something concrete to accept or redirect, not a naked menu. This is the generative half; don't collapse to the first idea.

### 4. Converge — settle the structure
Resolve the structural decisions a coherent draft needs — the architecture, the phases, the scope boundary — one at a time, each with a recommended answer. Then **stop**: deliberately leave the deeper, thin, or still-uncertain spots for grillkit rather than grinding every edge case here. Record those under **Open questions** in the doc so the hardening step has a target.

### 5. Write the plan document
Write `docs/plans/plan-<slug>-YYYY-MM-DD.md`, where `<slug>` is a short lowercase kebab-case name for the feature and the suffix is the plan's ISO creation date (`plan-sso-login-2026-07-23.md`). Keep that date stable on later edits; record an updated date inside the document when useful. Use the [plan-doc format](#plan-doc-format) below — it is the contract grillkit and issuekit both read, so keep the body phase/task-shaped. Create `docs/plans/` if it doesn't exist. If a plan for this work already exists, update it in place rather than writing a second file. For a genuine same-day collision between distinct plans, make the slug more specific; only as a last resort insert a sequence immediately before the date (`plan-sso-login-02-2026-07-23.md`).

### 6. Hand off
Report where the plan landed and offer the next step, in order, naming a sibling kit only when it is installed and otherwise describing the action in plain language:

- **grillkit** — pressure-test and harden the draft (it can update this same file in place).
- **issuekit** — turn the hardened plan into GitHub issues.

If the planning surfaced project vocabulary worth pinning down or a hard-to-reverse trade-off decision, offer **domainkit** when installed; otherwise offer to record a glossary entry or ADR directly.

Do not start either yourself.

## Plan-doc format

The canonical structure plankit owns. Keep it lean — every section earns its place — and keep the body organized as phases/tasks so issuekit can decompose it into issues:

```markdown
# Plan — <title>

## Context
The problem, why it matters now, and the outcome that means success.

## Design decisions (settled)
| Decision | Resolution |
|----------|-----------|
| <the choice> | <what we picked and, briefly, why> |

## Approach
The plan body as phases/milestones/tasks — each a concrete, verifiable unit of work. This is the structure issuekit reads to propose an issue breakdown.

## Open questions
Unresolved or thin spots, written as targets for grillkit to interrogate.

## Non-goals
Explicit scope boundaries — what this plan deliberately does not cover.
```

## Notes

- **Plan only.** No application code, no issues — those are separate steps (implementkit, issuekit). plankit hands off; it doesn't cross into them.
- **Fewest honest sections.** Prefer a short, sharp plan over a padded one; drop a section rather than fill it with filler. Scale the doc to the work's real surface area.
- **Defer the grilling.** It's fine — expected — to leave open questions. Draft a coherent plan and let grillkit harden it; don't try to be both.
- **Follow the repo's conventions.** If the codebase has its own plan/RFC/PRD location or template, follow that and say you did, rather than forcing `docs/plans`.
- No filesystem or shell (e.g. a browser-based agent)? Then you can't write the file — instead print the finished plan document as a codeblock and give the user the canonical `plan-<slug>-YYYY-MM-DD.md` filename to save wherever they keep plans.
