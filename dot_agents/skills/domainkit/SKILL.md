---
name: domainkit
description: >-
  Maintain a project's domain model as a consented byproduct of design work — a CONTEXT.md glossary of the ubiquitous language and docs/adr/ decision records. Use when a domain term needs pinning down or is used inconsistently, when a hard-to-reverse trade-off decision gets settled, when the user says "record this decision", "write an ADR", "update the glossary/ubiquitous language", "add this term", or when another skill needs to keep the domain model current — it scribes the model, it doesn't interrogate it.
license: MIT
allowed-tools: Read, Write, Edit, Glob
metadata:
  internal: false
---

# domainkit

Scribe of the project's **domain model**. domainkit keeps two living artifacts current as work happens: **`CONTEXT.md`**, a glossary of the project's ubiquitous language, and **`docs/adr/`**, the log of architectural decisions and why they were made. Its loop is narrow on purpose — **detect the moment, offer to record it, write on consent** — so the vocabulary and the reasoning behind hard choices stay pinned down without anyone remembering to do it.

It runs primarily as a **byproduct of design work**, though explicit invocation is supported. While a decision is being grilled, a plan drafted, or code written, a term crystallizes or a decision lands — that's when domainkit fires, proposes the entry, and writes it once you say yes.

## When this fires

A **domain term** needs pinning down — it's vague, overloaded, or two words are being used for one concept — or a **decision** gets settled that meets the ADR bar (below). Also on explicit asks: "record this decision", "write an ADR", "update the glossary", "add this term to the ubiquitous language", "/domainkit". And when another skill needs the domain model kept current, it defers here rather than carrying the format itself.

Two things it deliberately is **not**:

- **Not the interrogator.** Challenging a term, inventing edge-case scenarios, stress-testing whether a decision holds — that's an interrogation step. domainkit records the *settled* understanding; if a term or decision is still genuinely unresolved, use grillkit when installed or ask the user to settle it directly rather than writing down a guess.
- **Not a status tracker.** There is no `status.md` and no "current state" file. Project status is ambient — issues track what's planned, git and session history track what happened, a handoff compacts state on demand. domainkit persists only what those *can't* recover: the vocabulary and the reasoning behind irreversible choices.

## Procedure

Every write is **consent-gated** — detect, offer, then write only on a yes. A misfire costs one dismissible offer, never a spurious file.

### 1. Detect the moment
A term is being used loosely or inconsistently, or a settled decision clears the three-part ADR bar. In flow, this surfaces mid-grill, mid-plan, or mid-implementation — you don't wait to be called.

### 2. Locate the existing artifacts
Read the repo-root `CONTEXT.md` if it exists (or `CONTEXT-MAP.md` → the right context file for a multi-context project). If neither exists, create `CONTEXT.md` at the repo root when the first glossary term is accepted. For an ADR, scan `docs/adr/adr-*.md` and take the highest existing decision number.

### 3. Offer
Show the proposed glossary entry or ADR and ask before writing. Keep the proposal tight enough to accept or redirect at a glance.

### 4. Write on consent
- **Glossary** — add or adjust the term in place. Keep `CONTEXT.md` a *pure glossary*: what terms mean, nothing else. Be opinionated — when several words compete, pick one canonical term and list the rest under `_Avoid_`.
- **ADR** — create `docs/adr/adr-NNNN-<slug>-YYYY-MM-DD.md` at the next number, using a short lowercase kebab-case slug and the decision's ISO creation date (for example, `adr-0007-use-postgres-2026-07-23.md`). Minimal by default; add optional sections only when they carry real value. ADR content is **immutable** once shipped; the `Status` field is the one mutable exception, so a later ADR may mark the old record `deprecated` or `superseded by ADR-NNNN`.

### 5. Defer when unsettled
If the term or decision isn't actually resolved, don't manufacture certainty — use grillkit to settle it first when installed, or ask the user to settle it directly, then record the result.

## CONTEXT.md — the glossary format

`CONTEXT.md` is the single source of truth for **what words mean** in this project — a Domain-Driven-Design ubiquitous language, not a spec and not a status file.

```markdown
# <Context name>

<1–2 sentence description of this context.>

## <Optional grouping subheading>

### <Term>
<Tight definition — what it *is*, in 1–2 sentences.>
_Avoid: <synonym to reject>, <another>_
```

- **Content allowed** — terms specific to *this* project's domain; concepts unique to the work.
- **Content forbidden** — general programming concepts (timeouts, error types, utility patterns), however heavily used. If it isn't domain-specific, it doesn't belong here.
- **Definition style** — define *what a term is*, not what it does; one or two sentences.
- **Be opinionated** — when multiple words exist for one concept, choose the best and push the others to `_Avoid_`.
- **No size cap** — a glossary grows with the domain; never evict a real term to hit a length target.
- **Multiple contexts** — when bounded contexts clearly diverge, keep a `CONTEXT-MAP.md` at the repo root listing each context, where its file lives, and the relationships between them; split lazily, only once one file stops making sense.

## ADR — the decision record format

ADRs live in `docs/adr/` and use `adr-NNNN-<slug>-YYYY-MM-DD.md`, numbered sequentially with zero-padding: `adr-0001-use-postgres-2026-07-23.md`, `adr-0002-adopt-event-log-2026-07-24.md`, … The number is the authoritative decision order and the ISO suffix is the creation date; never rename an ADR merely because its status changes later. To number a new one, scan `docs/adr/` for the highest existing decision number and increment. Create the directory only when the first ADR is needed. Parallel branches may claim the same number; when that happens, renumber the later ADR during merge and update any references to it.

```markdown
# NNNN — <Title>

<1–3 sentences: what the context was, what was decided, and why.>

## Status
proposed | accepted | deprecated | superseded by ADR-NNNN

## Considered Options
- <rejected alternative worth remembering, and why it lost>

## Consequences
- <non-obvious downstream effect>
```

A single paragraph — title plus the context/decision/why — is already a valid ADR. `Status`, `Considered Options`, and `Consequences` are **optional**; include one only when it adds value.

**Write an ADR only when all three hold:**

1. **Hard to reverse** — changing course later carries real cost.
2. **Surprising without context** — a future reader will question the approach from the code alone.
3. **A genuine trade-off** — real alternatives existed and were weighed.

Typical qualifiers: architectural structure (monorepo layout, event sourcing), integration approaches between contexts, technology choices with high switching cost (database, auth provider), boundary and scope definitions, deliberate deviations from convention, constraints invisible in code (compliance, performance), and non-obvious rejections of an alternative.

## Notes

- **Consent holds even when auto-fired.** Being model-invoked never means writing unprompted — the offer always comes first.
- **Bias toward the high bar.** Better to fire on a genuinely conflicting term or a genuinely irreversible decision than to nag on every noun; when in doubt, stay quiet.
- **No filesystem or shell** (e.g. a browser-based agent)? Print the proposed glossary entry or ADR as a codeblock for the user to save, and skip the file write — everything else is unchanged.
