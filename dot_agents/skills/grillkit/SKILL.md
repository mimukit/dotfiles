---
name: grillkit
description: >-
  Grill the user relentlessly about any idea, plan, or design — one decision at a time, each with a recommended answer, until you both share the same picture. Use when the user wants to stress-test or pressure-test an idea, says "grill me", "grill this plan", "poke holes in this", "interrogate my design", or otherwise asks to interrogate a concept before committing to it — a rough idea, a plan file, an architecture, or a PR.
license: MIT
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion
metadata:
  internal: false
---

# grillkit

Interview the user relentlessly about their idea until the two of you reach a genuinely shared understanding. The subject can be anything — a rough concept, a design in their head, an existing plan file, an architecture, a PR — you don't need a formal plan to grill. Do not start building; the point is to surface every unresolved decision *first*.

## How to grill

- **Open by reflecting the idea back.** Before the first question, restate the subject in your own words — the goal you understand, the shape you're about to grill. This surfaces a misread up front, so you and the user are grilling the same idea rather than diverging silently for ten questions.
- **Walk the design tree.** Move branch by branch through the plan, resolving dependencies between decisions in order — an early choice often constrains a later one, so settle the upstream decision before raising what depends on it.
- **One question at a time.** Ask a single question, then wait for the answer before asking the next. Batching questions is bewildering and lets half of them go unanswered. Use `AskUserQuestion` (or the host's equivalent) when available.
- **Always recommend an answer.** For every question, state the option you'd pick and why. A naked question offloads the thinking; a recommendation gives the user something concrete to accept, reject, or refine.
- **Look up facts; ask only for decisions.** If something is discoverable by reading the codebase, docs, or config, find it yourself instead of asking. Reserve your questions for genuine *decisions* — the judgment calls that are the user's to make.
- **Probe the soft spots.** Push hardest on unstated assumptions, hand-waved edge cases, error and failure paths, scope boundaries, and anything described vaguely. If an answer is thin, follow up rather than moving on.

## When to stop

Keep going until the open decisions are resolved and the user confirms you share the same understanding. Then briefly recap the decisions you settled together, and do not begin implementing until the user explicitly says to proceed.

## What to do with the result

grillkit's job is the shared understanding, not a particular file — so end with the recap and let the user decide where it goes. After recapping, **ask** what to do with the settled decisions:

- **Update an existing file in place** — e.g. fold the hardened decisions back into the plan document you grilled (the workflow path when the input was a `plan-<slug>-YYYY-MM-DD.md`). Rewrite that same file; don't spawn a parallel copy or change its creation-date suffix.
- **Write a standalone note** — drop the decisions into a new file in the current directory, wherever the user wants it.
- **Nothing** — leave the recap in the conversation and stop.

**Never write a file unprompted, and don't assume a location.** grillkit doesn't own a canonical plan-doc format or a `docs/plans` convention. Here you're persisting a decision recap where the user asks, in whatever shape fits.

If grilling settled a domain term or a hard-to-reverse trade-off decision worth keeping, **domainkit** is the scribe when installed; otherwise note the settled decision for the user to record as a glossary entry or ADR. grillkit does the interrogating rather than owning that format.
