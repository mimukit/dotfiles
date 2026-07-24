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

grillkit's job is the shared understanding, not a particular file — but where that understanding lands depends on how the session started:

- **Started from a plan file** — when the input was an existing plan document (e.g. a `plan-<slug>-YYYY-MM-DD.md`), **fold the settled decisions back into that same file by default**, without asking. The user handed you a plan to harden; returning it hardened is the expected outcome. Rewrite that same file in place — don't spawn a parallel copy or change its creation-date suffix — and tell the user you updated it. Only skip or redirect the write if the user explicitly asked for something else (a standalone note, no file, a different location). **Stamp the hardened plan** with a `Grilled: YYYY-MM-DD` line near the top (today's date; update it on a re-grill). The stamp is a durable, machine-readable signal that this plan has survived a grill — downstream tooling reads it as provenance: issuekit, for one, only labels a plan's issues `ready` (safe for unattended work) when the source carries this stamp, and files ungrilled plans as `needs-planning` instead. No filesystem? Print the stamp line with the recap for the user to add themselves.
- **Started from anything else** — a rough idea, a design in someone's head, an architecture, a PR — there's no file to return to, so end with the recap and **ask** where the decisions should go: update some existing file in place, write a standalone note in the current directory, or nothing at all. Don't write a file unprompted and don't assume a location; grillkit doesn't own a canonical plan-doc format or a `docs/plans` convention.

If grilling settled a domain term or a hard-to-reverse trade-off decision worth keeping, **domainkit** is the scribe when installed; otherwise note the settled decision for the user to record as a glossary entry or ADR. grillkit does the interrogating rather than owning that format.
