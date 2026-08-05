---
name: researchkit
description: >-
  Research the credible options for a technical decision and recommend one — a tool, library, framework, architecture, or service — grounded in primary sources with cited, dated evidence. Use when the user asks "which should I use, A or B", "compare X and Y", "evaluate options for Z", "what's the best tool/library/service for …", "should we use X or Y", "research X before we build", or runs "/researchkit" — the decision research that front-runs a plan.
license: MIT
allowed-tools: WebSearch, WebFetch, Read, Grep, Glob, Write
metadata:
  internal: false
---

# researchkit

Research a "which should I use / which approach" question and **land a recommendation**. researchkit enumerates the credible options, investigates each against **primary sources** (official docs, source code, specs, first-party APIs, maintainer benchmarks — not blog hearsay), compares them on the constraints that actually matter, and picks one with a cited, dated rationale. It is decision research: the goal is a choice you can act on, not a neutral pile of notes.

It front-runs planning — answer "Drizzle or Prisma?", "which queue for this workload?", "REST or gRPC here?" first, then turn the chosen direction into a plan. If you use plankit, researchkit is the step before it.

## When this fires

Any "which one / which approach" question where the answer isn't obvious and the stakes justify looking: "compare X and Y", "which should I use", "evaluate options for Z", "what's the best library/tool/service for …", "should we use X or Y", "research X before we build", "/researchkit".

Three things it deliberately is **not**:

- **Not a neutral note-taker.** It always ends in a recommendation. If there's genuinely nothing to compare (one credible option survives), it degrades to a **cited explainer** of that option — but it never dumps opinion-free notes as the deliverable.
- **Not repo grounding.** Reading *this* codebase to reuse existing patterns is planning work, not researchkit's job. researchkit investigates the *external* landscape — tools, libraries, services, approaches.
- **Not implementation.** researchkit reads and cites; it never builds. See [Never build to find out](#never-build-to-find-out) — this is the boundary users most often see it cross, and crossing it is always a bug.

## Never build to find out

researchkit's deliverable is a cited argument, not a working artifact. It **never writes, runs, or scaffolds code to test a hypothesis** — no spike, no prototype, no benchmark harness, no throwaway repo, no `npm install` to see what happens, not even a "quick" one. This holds however tempting the shortcut looks and however much it would sharpen the recommendation.

The failure mode is specific and worth naming, because it feels helpful from the inside: research turns up a claim the docs don't settle, building a small test looks like the fastest way to settle it, and twenty minutes later the user is reading about a prototype they never asked for. The user asked which option to pick. Handing back an implementation instead answers a question they didn't ask, spends their time and tokens without consent, and buries the comparison they wanted.

So: surface the hypotheses and the evidence, then **stop and let the user choose**. If a spike is genuinely the only way forward, say that in Open questions — "settling this needs a spike: <what it would measure>" — and wait. Building one is a separate, explicitly requested job, and implementkit's, not researchkit's.

## Procedure

### 1. Frame the decision
Pin down what's actually being chosen and the constraints that decide it — the stack it plugs into, scale, budget, team familiarity, must-have features, hard constraints. If the ask is a bare one-liner, ask a couple of scoping questions first; the constraints are what turn a generic comparison into a real recommendation.

### 2. Find the credible options
Enumerate the real contenders — the ones a knowledgeable engineer would actually weigh. Don't pad the field with strawmen to look thorough. If only one option genuinely survives the constraints, say so and switch to explainer mode for that one.

### 3. Investigate against primary sources
Use whatever web search/fetch tools the host exposes to read the **authoritative** origin for each load-bearing claim — official docs, the source, the spec, the first-party API, a maintainer-published benchmark — over secondary interpretation. For every source, note its **version and date**, and flag when the evidence may be stale (a benchmark from an old major version, a doc that predates a rewrite). Trace each claim back to where it's actually established.

**No web access?** Say so plainly, then give a best-effort comparison from knowledge with an explicit staleness warning — and **never fabricate a citation**. A missing source is stated as missing, not invented.

**A claim the sources won't settle** — a performance number for your exact workload, whether two libraries actually interop, whether an API does what its docs imply — is **not a cue to go test it**. Mark it unverified, carry it into Open questions, and let the reader decide whether it's worth a spike. Unresolved is a legitimate research finding; a surprise prototype is not.

### 4. Compare
Lay the options against the constraints that matter (from [Frame the decision](#1-frame-the-decision)), not a generic feature grid. Each load-bearing claim in the comparison carries its source. Keep it to the axes that actually move the decision.

### 5. Recommend
Pick one. Give a one-line why, and state the condition under which you'd pick differently ("Drizzle — lighter runtime, no codegen; choose Prisma if you need its migration tooling and admin GUI"). A recommendation the reader can accept, reject, or redirect — not a shrug.

### 6. Hand off
Print the recommendation, then offer the next steps without starting either:

- **Save it?** — offer to write the artifact to `docs/research/research-<slug>-YYYY-MM-DD.md`, using a short lowercase kebab-case subject slug and the artifact's ISO creation date (for example, `research-auth-providers-2026-07-23.md`). Keep that date stable on later edits and update the same artifact in place. For a genuine same-day collision between distinct reports, make the slug more specific; only as a last resort insert a sequence immediately before the date (`research-auth-providers-02-2026-07-23.md`). Follow any established research/notes/RFC location or naming scheme the repository already uses. Default is inline-only; write the file only if the user wants a durable record.
- **Plan it?** — if the user works with plankit, offer to turn the chosen direction into a plan. Leftover uncertainties become the "open questions" that plankit and grillkit pick up. This nudge is optional — don't assume plankit is installed.

## Artifact format

Print inline by default; write to a file only when asked. Either way, the shape:

```markdown
# Research — <the question>

## Recommendation
<the pick> — <one-line why>. Choose <alternative> instead if <condition>.

## Options compared
| Option | <constraint A> | <constraint B> | Fit |
|--------|----------------|----------------|-----|
| ...    | ...            | ...            | ... |

## Evidence (primary sources)
- <load-bearing claim> → <source URL> (<version/date>) — ⚠ note if stale
- ...

## Open questions
Unresolved or thin spots to settle when planning — including any claim that would need a spike to settle, named but not acted on.
```

Scale it to the decision — a two-way library pick is a short block; an architecture choice earns more. Drop any section that would be filler.

## Notes

- **Execution.** Run synchronously in-session by default. Dispatch a background agent **only** if the host supports background agents *and* the user explicitly asks ("research this in the background"); otherwise degrade to sync silently — never block on a capability that may not exist.
- **Tools.** `allowed-tools` deliberately withholds shell and file-editing tools, so a host that honors it can't run a spike even if the model talks itself into wanting one. Hosts that ignore the field are bound by [Never build to find out](#never-build-to-find-out) instead — the prose is the real rule, the tool list is the backstop.
- **Evidence over recall.** The whole reason this beats asking the model directly is primary-source discipline. A recommendation with no traceable evidence is a guess wearing a table — cite the load-bearing claims or mark them unverified.
- **Freshness matters most in fast-moving areas.** For tooling/libraries where the landscape shifts, the version/date of each source is part of the finding, not decoration.
- **No filesystem or shell** (e.g. a browser-based agent)? Printing inline is already the default, so nothing changes — just skip the save-to-file offer.
