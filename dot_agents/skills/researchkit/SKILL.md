---
name: researchkit
description: >-
  Research the credible options for a technical decision and recommend one (a tool, library, framework, architecture, or service) grounded in primary sources with cited, dated evidence. Use when the user asks "which should I use, A or B", "compare X and Y", "evaluate options for Z", "what's the best tool/library/service for …", "should we use X or Y", "research X before we build", or runs "/researchkit", the decision research that front-runs a plan.
license: MIT
allowed-tools: WebSearch, WebFetch, Read, Grep, Glob, Write, AskUserQuestion
metadata:
  internal: false
---

# researchkit

Research a "which should I use / which approach" question and **land a recommendation**. researchkit enumerates the credible options, investigates each against **primary sources** (official docs, source code, specs, first-party APIs, maintainer benchmarks, not blog hearsay), compares them on the constraints that actually matter, and picks one with a cited, dated rationale. It is decision research: the goal is a choice you can act on, not a neutral pile of notes.

It front-runs planning. Answer "Drizzle or Prisma?", "which queue for this workload?", "REST or gRPC here?" first, then turn the chosen direction into a plan. If you use plankit, researchkit is the step before it.

## When this fires

Any "which one / which approach" question where the answer isn't obvious and the stakes justify looking: "compare X and Y", "which should I use", "evaluate options for Z", "what's the best library/tool/service for …", "should we use X or Y", "research X before we build", "/researchkit".

Two things it deliberately is **not**:

- **Not a neutral note-taker.** It always ends in a recommendation. If there's genuinely nothing to compare (one credible option survives), it degrades to a **cited explainer** of that option, but it never dumps opinion-free notes as the deliverable.
- **Not repo grounding.** Reading *this* codebase to reuse existing patterns is planning work, not researchkit's job. researchkit investigates the *external* landscape: tools, libraries, services, approaches.

## Never build to find out

researchkit's deliverable is a cited argument, not a working artifact. This is the boundary users most often see it cross, and crossing it is always a bug. It **never writes, runs, or scaffolds code to test a hypothesis**: no spike, no prototype, no benchmark harness, no throwaway repo, no `npm install` to see what happens, not even a "quick" one. This holds however tempting the shortcut looks and however much it would sharpen the recommendation.

The failure mode is specific and worth naming, because it feels helpful from the inside: research turns up a claim the docs don't settle, building a small test looks like the fastest way to settle it, and twenty minutes later the user is reading about a prototype they never asked for. The user asked which option to pick. Handing back an implementation instead answers a question they didn't ask, spends their time and tokens without consent, and buries the comparison they wanted.

So: surface the hypotheses and the evidence, then **stop and let the user choose**. If a spike is genuinely the only way forward, say that in Open questions ("settling this needs a spike: <what it would measure>") and wait. Building one is a separate, explicitly requested job: **prototypekit**'s when it's installed, and otherwise a throwaway the user asks for by name. It is never researchkit's, and it is not the build step's either, because that one needs a settled intent and ships production code.

## Procedure

### 1. Frame the decision
Pin down what's actually being chosen and the constraints that decide it: the stack it plugs into, scale, budget, team familiarity, must-have features, hard constraints. If the ask is a bare one-liner, ask scoping questions first, in one round, only about the constraints the ask leaves open; the constraints are what turn a generic comparison into a real recommendation.

**Done when** the decision is one sentence and every deciding constraint has a value or an explicit "does not matter".

### 2. Find the credible options
Enumerate the real contenders, the ones a knowledgeable engineer would actually weigh. Don't pad the field with strawmen to look thorough. If only one option genuinely survives the constraints, say so and switch to explainer mode for that one.

**Done when** every option that meets the hard constraints and that a knowledgeable engineer would weigh is on the list, and each well-known option left off carries a one-line reason.

### 3. Investigate against primary sources
Use whatever web search/fetch tools the host exposes to read the **authoritative** origin for each load-bearing claim (official docs, the source, the spec, the first-party API, a maintainer-published benchmark) over secondary interpretation. For every source, note its **version and date**, and flag when the evidence may be stale (a benchmark from an old major version, a doc that predates a rewrite). Trace each claim back to where it's actually established.

**Refresh a source before you rely on it** when any of these holds: it describes a version older than the option's current release line; it predates the option's latest major release or a rewrite; it is more than 12 months old in a fast-moving area (frameworks, hosted services, AI tooling); or you are updating a saved research artifact, in which case re-fetch every load-bearing source in it. A source with no newer replacement stays in, marked ⚠ stale with its date.

**No web access?** Say so plainly, then give a best-effort comparison from knowledge under the **Provisional comparison** heading of the [artifact format](#artifact-format), and **never fabricate a citation**. A missing source is stated as missing, not invented.

**A claim the sources won't settle** (a performance number for your exact workload, whether two libraries actually interop, whether an API does what its docs imply) stays unverified. Carry it into Open questions with what a measurement would need to show.

**Done when** every load-bearing claim in the comparison has a source with its version and date, or sits in Open questions as unverified.

### 4. Compare
Lay the options against the constraints that matter (from [Frame the decision](#1-frame-the-decision)), not a generic feature grid. Each load-bearing claim in the comparison carries its source. Keep it to the axes that actually move the decision.

**Done when** every row of the comparison holds a value for every constraint axis, and each value either cites its source or is marked unverified.

### 5. Recommend
Pick one. Give a one-line why, and state the condition under which you'd pick differently ("Drizzle, for its lighter runtime and no codegen; choose Prisma if you need its migration tooling and admin GUI"). Give a recommendation the reader can accept, reject, or redirect, not a shrug. When any load-bearing claim behind the pick is unverified or comes from recall, label the recommendation **provisional** and name the claim.

### 6. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Print the recommendation. Then ask once whether to save it. On yes, write the artifact to `docs/research/NNNN-research-<slug>-YYYY-MM-DD.md`, using the next serial, a short lowercase kebab-case subject slug, and the artifact's ISO creation date (for example, `0003-research-auth-providers-2026-07-23.md`). To get the serial `NNNN`, list `docs/research/`, take the highest leading four-digit serial, and add one; start at `0001` when there is none. The serial is per directory and never reused. Keep the whole name stable on later edits and update the same artifact in place. Follow any established research/notes/RFC location or naming scheme the repository already uses. Default is inline-only; write the file only if the user wants a durable record.

**Where it landed.** Give the file path, or say the report is in the chat only.

**Next.** Crown one move, and start none of them:

- **A load-bearing open question needs a measurement** → spike it with **prototypekit** when installed, otherwise a throwaway test the user asks for by name. The pick waits on that answer.
- **Otherwise** → turn the chosen direction into a plan with **plankit** when installed, otherwise write the plan directly. The open questions carry into the plan.

## Artifact format

Print inline by default; write to a file only when asked. Either way, the shape:

```markdown
# Research: <the question>

## Recommendation
<the pick>: <one-line why>. Choose <alternative> instead if <condition>.

## Options compared
| Option | <constraint A> | <constraint B> | Fit |
|--------|----------------|----------------|-----|
| ...    | ...            | ...            | ... |

## Evidence (primary sources)
- <load-bearing claim> → <source URL> (<version/date>), ⚠ note if stale
- ...

## Provisional comparison (from recall, not verified)
- <claim> (as of <your knowledge cutoff>)

## Open questions
Unresolved or thin spots to settle when planning, including any claim that needs a measurement, with what the measurement would show.
```

**Evidence holds only claims you fetched in this run.** A claim from recall goes under **Provisional comparison**, never under Evidence, so a reader sees at a glance which claims a source backs. Drop the Provisional section when every claim is sourced; drop Evidence when there was no web access.

Scale it to the decision. A two-way library pick is a short block; an architecture choice earns more. Drop any section that would be filler.

## Notes

- **Execution.** Run synchronously in-session by default. Dispatch a background agent **only** if the host supports background agents *and* the user explicitly asks ("research this in the background"); otherwise degrade to sync silently, and never block on a capability that may not exist.
- **Tools.** `allowed-tools` deliberately withholds shell and file-editing tools, the backstop for [Never build to find out](#never-build-to-find-out) on hosts that honor the field.
- **Evidence over recall.** The whole reason this beats asking the model directly is primary-source discipline. A recommendation with no traceable evidence is a guess wearing a table, so cite the load-bearing claims or mark them unverified.
- **Freshness matters most in fast-moving areas.** For tooling/libraries where the landscape shifts, the version/date of each source is part of the finding, not decoration.
- **No filesystem or shell** (e.g. a browser-based agent)? Printing inline is already the default, so nothing changes; just skip the save-to-file offer.
