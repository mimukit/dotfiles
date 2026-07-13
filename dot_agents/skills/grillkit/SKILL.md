---
name: grillkit
description: >-
  Grill the user relentlessly about a plan or design before any code is written — one decision at a time, each with a recommended answer, until you both share the same picture. Use when the user wants to stress-test or pressure-test a plan, says "grill me", "grill this plan", "poke holes in this", "interrogate my design", or otherwise asks to interrogate an idea before building.
license: MIT
allowed-tools: Read, Grep, Glob, AskUserQuestion
metadata:
  internal: false
---

# grillkit

Interview the user relentlessly about their plan until the two of you reach a genuinely shared understanding. Do not start building — the point is to surface every unresolved decision *first*.

## How to grill

- **Walk the design tree.** Move branch by branch through the plan, resolving dependencies between decisions in order — an early choice often constrains a later one, so settle the upstream decision before raising what depends on it.
- **One question at a time.** Ask a single question, then wait for the answer before asking the next. Batching questions is bewildering and lets half of them go unanswered. Use `AskUserQuestion` tool or similar tool for better UX if available.
- **Always recommend an answer.** For every question, state the option you'd pick and why. A naked question offloads the thinking; a recommendation gives the user something concrete to accept, reject, or refine.
- **Look up facts; ask only for decisions.** If something is discoverable by reading the codebase, docs, or config, find it yourself instead of asking. Reserve your questions for genuine *decisions* — the judgment calls that are the user's to make.
- **Probe the soft spots.** Push hardest on unstated assumptions, hand-waved edge cases, error and failure paths, scope boundaries, and anything described vaguely. If an answer is thin, follow up rather than moving on.

## When to stop

Keep going until the open decisions are resolved and the user confirms you share the same understanding. Then briefly recap the decisions you settled together, and do not begin implementing until the user explicitly says to proceed.

Finally offer user to create a plan/prd/spec document in `./docs/plans` directory.