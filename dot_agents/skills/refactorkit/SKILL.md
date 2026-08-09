---
name: refactorkit
description: >-
  Survey an existing codebase for the structural change worth making — shallow interfaces, adapter sprawl, poor locality, untested coupling — rank the candidates, crown one, and write it up as a reviewable proposal. Use when the user says "where should I refactor", "what's wrong with this codebase's structure", "find refactoring opportunities", "this code is hard to change", "improve our architecture", "audit the module boundaries", or "/refactorkit". It proposes and never edits code.
license: MIT
allowed-tools: Bash, Read, Grep, Glob, Write, Task, Agent, Skill
metadata:
  internal: false
---

# refactorkit

The survey you run on a codebase you already have. refactorkit reads the repo — its churn, its module shapes, its tests — finds where the *structure* is costing you, ranks the candidates against two gates, crowns exactly one, and writes it up as a proposal somebody can argue with.

It is a single procedure, optionally scoped to a subtree (`/refactorkit src/payments`). There are no modes: everything it does, it does the same way on every run.

## It proposes, it never edits

**refactorkit writes exactly one Markdown file and touches no source code.** No moves, no renames, no extractions, no "small tidy-up while I'm in here." The name says *refactor*; the skill only ever says *where and why*, and the doing belongs to whoever picks the proposal up. That boundary is the whole reason the report can be trusted — a survey that also edits has already decided, and you're reading a rationalization rather than a recommendation.

`Edit` is deliberately absent from this skill's tools. The one file it creates is new, so `Write` covers it.

## When this fires

"Where should I refactor this", "what's wrong with this codebase's structure", "find refactoring opportunities", "this code is hard to change", "improve our architecture", "audit the module boundaries", "the seams here are a mess", "/refactorkit".

Four boundaries, one line each:

- **Not a code review** — a review reads a *diff* for defects in work someone just did. refactorkit reads the *tree* for structure that predates the diff. A "review my changes" request is not this skill.
- **Not documentation** — describing the architecture as it stands is a different job; refactorkit only ever describes an architecture that doesn't exist yet.
- **Not visual design** — nothing here concerns UI, styling, or a design system, despite what "design" suggests when it sits next to "refactor."
- **Not a decision record** — refactorkit produces a proposal, not a ratified decision. When the proposal supersedes an existing architecture decision, it says so and routes to whatever records decisions in this repo.

## The vocabulary

Use these terms precisely; they're what keeps the findings from collapsing into generic smell-listing.

- **Module** — anything with an inside and an outside: a file, a class, a package, a service. Not a language construct, a boundary.
- **Interface** — everything a caller must know to use the module correctly. Not just the signature: also the ordering constraints, the required config, the side effects, the error contract, and the invariants nobody wrote down. Interfaces are almost always bigger than they look.
- **Depth** — how much behaviour a module hides, relative to how much interface it makes you learn. A deep module buys a lot of hidden work for a small interface. A shallow one charges nearly the same either way.
- **Seam** — the place a system can be split without tearing: where one side can be replaced, faked, or tested without the other.
- **Adapter** — a module whose entire job is reshaping data between two others. Adapters aren't wrong; a *cluster* of them is a symptom that two sides disagree about a shape.
- **Locality** — how much of one conceptual change lands in one place. Good locality means a feature change touches few files; poor locality means it fans out.
- **Leverage** — how much future change a fix makes cheaper. It's what breaks ties between candidates that are otherwise equally sound.

**Use the project's own domain terms throughout.** If the codebase says *ledger*, *tenant*, *shipment*, the proposal says those words. Falling back on generic "component," "service," "API," or "layer" is the single clearest sign a finding was pattern-matched rather than read — and it's what makes architecture advice sound plausible while saying nothing.

## The four friction patterns

A **closed set**. These four are what refactorkit looks for, and it looks for nothing else. The closure is load-bearing: an open-ended hunt for "problems" produces the same generic list on every codebase, which is exactly the output this skill exists to replace. All four reduce to depth — each one is a different way an interface costs more than the behaviour behind it.

| Pattern | What it is | The shape to look for | Who finds it |
|---|---|---|---|
| Shallow interface | the interface costs about as much to learn as the implementation costs to read | a unit whose members each forward to exactly one member of exactly one other unit | subagent |
| Adapter prevalence | modules that exist only to reshape data between two others — the finding is that two sides disagree on a shape, never "delete the adapters" | a cluster of translation-only units sitting on one boundary, translating in both directions | subagent |
| Untested coupling | behaviour you can only test by standing up its collaborators | tests that construct more collaborators than they make assertions, or an untested unit whose neighbours are all tested | subagent |
| Poor locality | one conceptual change fans out across many files | files that repeatedly change in the same commits while living in different parts of the tree | **main session** |

**Signals are shapes, never names.** Do not hunt for `*Mapper`, `*Adapter`, `*DTO`, `*Service`, or any other suffix. Those conventions belong to one or two language communities and mean nothing in a Go, Rust, Elixir, or PHP repo — and a named example is precisely what an agent pattern-matches on instead of reading. Derive the repo's own conventions first (the guardrails read below usually hands them to you), then look for the *structure* described above under whatever names this codebase happens to use.

## The two gates

Every candidate clears both before it is listed at all. A candidate that fails either one is discarded silently — it does not appear as a weaker finding, and it does not appear with a caveat.

**The deletion test.** If this module vanished and its callers absorbed what it did, would complexity *concentrate* where it belongs, or merely *relocate*? Concentration is the win. Relocation is churn wearing a refactor's clothes, and printing it is how a report gets long and stops being read. State the verdict with one sentence of evidence — which callers absorb what, and why that is or isn't a better home.

**Interface as test surface.** After the proposed change, can the behaviour be tested through the new interface alone, without reaching inside? If not, the seam is in the wrong place: the candidate is *unfinished*, not ready. This gate is what stops a proposal that merely moves the boundary from passing as a proposal that improves it.

Both verdicts are mandatory on every listed candidate, in the terminal output and in the file. A candidate whose gate verdicts aren't stated is not a weaker candidate; it's an unevidenced one.

## The strength scale

Rate each surviving candidate against this table rather than by feel — an undefined badge is a vibe wearing a label, and strength is the one column a reader trusts without checking.

| Strength | What it takes | How it ranks |
|---|---|---|
| `strong` | both gates pass, the files sit in the churn top slice, and the blast radius is named in actual files | crownable |
| `moderate` | both gates pass, but the code is cold or the blast radius is wide | crownable only when nothing is `strong` |
| `weak` | gates pass, but the win is stylistic — nothing changes about what a caller must know | listed, **never crowned** |

## Procedure

### 1. Read the guardrails first

Before looking at any code, read what the repo has already decided:

- a repo-root context or glossary file (commonly `CONTEXT.md`) for the ubiquitous language — this is where the project's own domain terms come from, and where its naming conventions usually surface;
- `docs/adr/` (or wherever this repo keeps architecture decision records) for decisions already made.

A proposal that reverses an accepted decision record must **say so by its number** and route to a superseding record rather than quietly re-suggesting a design that was already rejected. Reversing a decision is legitimate; doing it without noticing is not.

Neither file existing is normal. Degrade silently — no warning, no commentary.

### 2. Rank by churn, then cluster

`git log --format= --name-only --since=<a year or so>` gives both signals refactorkit needs in one read, with no tool beyond git: how often each file changes (the churn ranking) and which files keep changing *together* (the co-change pairs that become the poor-locality finding).

Rank files by change count, then group the hot ones into **3–5 coherent areas** — by directory, by feature, by whatever seam the repo actually has. Honour the scope argument when the user gave one: scope narrows the tree, it doesn't change the method.

**No git history** — a shallow clone, or not a repo at all — means no ranking. Scan by structure instead and say plainly that the prioritisation was skipped, so nobody reads the coverage line as more than it is.

### 3. Fan out, one agent per cluster

Dispatch one subagent per area. Each applies the three read-the-code patterns from [The four friction patterns](#the-four-friction-patterns) to its own slice, runs both gates itself, and returns a list of candidate records — or an explicit empty result, which is a perfectly good answer.

Give every agent the same fixed return shape, because the main session has to rank findings it never gathered. Freeform prose can't be ranked without re-reading everything the agent read, which throws away the entire reason to fan out:

| Field | Content |
|---|---|
| `pattern` | one of the three read-the-code patterns |
| `files` | the paths involved |
| `shape` | the proposed structure, one line |
| `deletion_test` | verdict plus one sentence of evidence |
| `test_surface` | verdict plus one sentence of evidence |
| `blast_radius` | files touched, callers changed |
| `strength` | per [The strength scale](#the-strength-scale) |

**Poor locality stays in the main session.** It's derived from the co-change pairs already in hand, it costs no file reads, and a per-area agent structurally *cannot* see files that change together while living in different areas. Handing it to an area agent guarantees it is never found.

**No subagent tool available → scan the top churn slice inline instead**, applying the same patterns and the same gates, and say which path the run took. For a public skill this fallback is a large share of runs rather than an edge case, so it is a real mode with a real coverage claim, not a degraded apology.

### 4. Synthesize, gate, rank, crown

- **Drop** any record missing a gate verdict. Dropped, not repaired — an unevidenced gate is exactly what the deletion test exists to catch, and repairing it in the main session means asserting a verdict on code you didn't read.
- **Dedupe** across areas; the same seam often surfaces from both sides of it.
- **Rank** on strength, then leverage, then lowest blast radius.
- **Crown exactly one.** Never a `weak` candidate, whatever else is on the list. The rest become runners-up, in order.

Crowning one is the work. A list of five equal-looking options is the state you were already in before running this.

### 5. Report, then write the artifact

Print a compact table first — candidate, pattern, strength, blast radius — then the crowned move with its reasoning, then the runners-up.

**Every report carries a coverage line**, in the terminal and in the file: *"ranked 1,240 files by churn, read the top 40 across 4 areas."* A cap nobody can see is a lie about completeness, and it's the difference between "there's nothing structurally wrong here" and "I looked at 3% of it."

**The artifact** goes to `docs/refactor/refactor-<slug>-YYYY-MM-DD.md` — a lowercase type prefix, a short lowercase kebab-case subject slug, and the ISO creation date at the end. Keep that creation date stable when the file is edited; a re-run on the same subject **updates the same file in place** rather than spawning a dated copy. When the repo already has an established home or naming scheme for proposal documents, that convention wins.

It contains: the coverage line, the ranked table, then one section per candidate — the problem, the proposed shape, why it is deeper, both gate verdicts, the blast radius — with a **Mermaid before/after diagram for the crowned candidate** at minimum. GitHub and most editors render Mermaid natively, which is what makes a generated HTML report unnecessary.

This file is **durable and committable** — it's a proposal meant to be reviewed in a PR, not scratch. refactorkit still never commits it.

**No writable filesystem** (a browser-based agent) → print the artifact as a codeblock under its canonical path and skip the write.

### 6. Hand off

**What changed** — the report written, and explicitly: no source file touched. **Where it landed** — the path. **Next** — take the crowned candidate to a grilling: the write-up is already plan-shaped, and what it lacks is interrogation rather than drafting. Name **grillkit** when it's installed; otherwise say plainly that the move is to interrogate the proposal yourself — the assumptions, the failure paths, the blast radius — before anybody builds it.

Runners-up: route to a decision-record skill (**domainkit** when installed) when the proposal supersedes an existing record, and to a build skill (**implementkit** when installed, otherwise just building it) once the shape is settled.

**On an empty result, say there is no next move.** See below.

## When nothing clears the gates

A clean result is a real outcome, and refactorkit reports it as one: name the coverage, say nothing cleared the gates, and **write no file**.

This matters more than it looks. A survey obliged to produce findings will manufacture them, and manufactured architecture advice reads exactly like the real thing — same vocabulary, same confidence, same shape. The deletion test is only a genuine gate if "nothing here" is a legal answer.

The terminal line has to carry the coverage — *"scanned 38 files across `src/`; nothing cleared the deletion test"* — or an empty result is indistinguishable from a scan that never ran.

## Notes

- **Zero source mutation, always.** One new Markdown file is the entire write surface. Anything else — a rename, an extraction, a "quick fix" — is out of bounds even when it's obviously correct.
- **Read-only shell only.** git history, file reads, greps. Never install or run an analysis tool to generate evidence: probing for one and parsing its output couples this skill to a format that changes on a minor release. If the repo already has such an artifact on disk — a dependency graph, a coverage report — read it. Never generate one.
- **Route, don't launch.** Name the next kit and its one-line invocation; don't invoke it. Whether to act on a proposal is the reader's call, and a survey that chains itself into the build has taken that call away.
- **Route, don't require.** Every recommendation degrades to a plain action when the named kit isn't installed. refactorkit is useful in a bare repo with nothing but git.
- **Follow the repo over these defaults.** An established artifact location, a documented convention, or a stated policy in the repo's agent-guide file (`CLAUDE.md` or an equivalent) wins — say that you followed it.
