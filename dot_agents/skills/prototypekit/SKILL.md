---
name: prototypekit
description: >-
  Build throwaway code that answers a question — an interactive state model you can drive, a script that measures one thing, or competing UI mocks to choose between — then fold the answer into the decision and delete the code. Use when the user says "prototype this", "spike this", "throwaway explore X", "does this state model hold up", "will this design survive <hard case>", "is this library fast enough", "do these two actually interop", "show me a few options for this screen", "mock up three versions", or "/prototypekit". Not a demo generator and never production code.
license: MIT
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
metadata:
  internal: false
---

# prototypekit

Some decisions can't be settled by reading. Does this reducer survive partial refunds? Is this library fast enough for our load? What should this settings page actually look like? prototypekit writes code whose only job is to **answer** one of those, then throws the code away and keeps the answer.

That inversion is the whole skill. The prototype is not a draft of the real thing, not a head start, and not a demo — it is an instrument, and instruments get put away. Everything below exists to keep the code disposable and the answer durable.

## When this fires

"Prototype this", "spike this", "throwaway explore X", "does this state model hold up", "will this survive <hard case>", "is this fast enough", "do these two interop", "does this API do what its docs imply", "show me a few options for this screen", "mock up three versions", "/prototypekit".

Four things it deliberately is **not**:

- **Not the build step.** A build skill turns a *settled* intent into production code behind a test-and-build gate. prototypekit runs when the intent isn't settled *because nobody has seen it work*, writes code that fails every production standard on purpose, and gates on nothing.
- **Not the research step.** Research answers from primary sources and never builds. prototypekit answers by building and cites nothing. They're complements: when research hits a claim its sources won't settle, that claim comes here.
- **Not the UI builder.** A UI skill builds the screen that ships, conforming to the project's design system. prototypekit's mocks exist to be compared, chosen between, and deleted — and they deliberately *break* conformity, because three variants that all conform are three variants of one idea.
- **Not a demo generator.** This is the shape the request most often arrives disguised as. See [No question, no prototype](#no-question-no-prototype).

## No question, no prototype

Before writing a line, state **the question** and **the decision it unblocks**, one sentence each. If you can't write both, there is nothing to prototype yet.

An ask that resolves to "build me a demo", "make a proof of concept for the client", or "just try something" is production work under a softer name. **Bounce it once**, naming the reason and the route: it wants a plan and a real build, not a throwaway.

**If the user reaffirms, the ask converts — not the skill.** They've made a decision; arguing twice is not your job. Say plainly that this is production work, then do it *as* production work: no marker, no exclude entry, no disposal, and it stays on disk. prototypekit stops driving at that point. What you must never do is build a demo *as a marked, disposed prototype* — that hands someone a thing to show a client and then deletes it.

## The six rules

Both modes obey these.

1. **Throwaway from day one, and marked.** Live next to what you're prototyping so the project's imports, aliases, and config just work. Name every file `*.prototype.*` and every directory `*.prototype/`. The marker is not cosmetic — it is what the exclude entry matches, and an unmarked prototype is one `git add -A` away from `main`.
2. **Trivial to run.** One command from the project's own task runner, or a file you double-click. Discover the runner from the repo (`package.json`, `Makefile`, `justfile`, `pyproject.toml`, `go.mod`, `Cargo.toml`) rather than assuming one — and **name the command for the user to run; never start a dev server yourself.**
3. **No persistence.** State lives in memory. Persistence is usually the thing being questioned, not something to lean on. When the question genuinely involves a database, use a scratch one named so nobody mistakes it — `PROTOTYPE_wipe_me`.
4. **Skip the polish.** No tests, no abstractions, no error handling beyond what makes it run. prototypekit **never runs a done-gate**; there is nothing to gate.
5. **Surface the state.** Every action (logic) or variant switch (ui) shows the full relevant state. An invisible prototype answers nothing.
6. **Stop when the question is answered**, not when the prototype feels finished. The scope box is the check.

## Procedure

### 1. State the question and draw the scope box

Write the question and the decision it unblocks, per [No question, no prototype](#no-question-no-prototype).

Then draw the **scope box**: the cases that are **in**, and the cases explicitly **out**. This is the mechanism behind rule 6, and it exists because the drift is gradual and feels productive — a spike that works invites one more case, then error handling, then a component extraction, and the throwaway quietly becomes an app nobody chose to build. A case outside the box is a new decision: say so out loud and get agreement, don't absorb it.

The box goes in the prototype file's own header comment, so it's in front of you every time you reopen the file — which is exactly where the drift happens. Put any assumption you had to make beside it: a stated wrong assumption is correctable, a silent one isn't.

### 2. Route the branch

- A state model, a reducer, a flow, a backend module, a feasibility question → [the logic mode](#4-the-logic-mode).
- A page, a screen, a component → [the UI mode](#5-the-ui-mode).

Ambiguous and the user isn't reachable? Default by what surrounds the code and state the assumption in the header.

### 3. Mark it, exclude it, then write it

**Before the first file exists**, register the marker patterns in the repo's **private exclude** — not the tracked `.gitignore`. A tracked ignore edit is itself an uncommitted change that commit and review tooling will pick up, so the skill would leave a diff behind while claiming it left nothing; the private exclude is local-only and leaves tracked files untouched.

```sh
git rev-parse --git-path info/exclude    # resolve the real path; never hardcode .git/info/exclude
```

Ask git for that path rather than assuming it — in a linked worktree `.git` is a *file*, not a directory, so the literal path doesn't exist. Append `*.prototype.*` and `*.prototype/` only if they aren't already listed. Both patterns ship, because the file glob won't match a directory on its own.

**Say you did it in the same line** you say where the prototype is going, so the user knows the guard is in place before any code lands.

### 4. The logic mode

**First axis — does the code already exist?**

- **It exists.** Import the real module and run it through the project's own runner, rendering however the project can — a throwaway dev route, a CLI harness, a script. This is what living in the working tree bought you, and it's the only shape that tests the actual code. **Never re-type logic you already have; import it. If you can't import it, the prototype is testing your typing.**
- **You're inventing it.** One self-contained file. For a web project that's HTML with no build step and no server — double-click to open, and shareable as a single attachment to someone who doesn't have the repo. For anything else, that language's simplest runnable single file.

**Second axis — who reads the output?**

- **A human clicking.** Build the interactive shape: **free-play controls** that can fire every transition, plus **guided walkthroughs** that push the model through the specific hard cases the question is about — the ones nobody can reason about on paper. Render the full state after every action. A non-developer must be able to drive it, because "does this feel right" is frequently a question only a non-developer can answer.
- **A number or a log** — is this fast enough, do these two interop, does this API do what its docs imply. Write a script that prints the measurement *and the conditions it was taken under*. A number with no conditions attached isn't evidence.

Same gate, same scope box, same disposal across all four combinations; only the render target changes.

### 5. The UI mode

**Three structurally different variations on a single route**, switched by a URL search param with a small floating switcher. One route means one dev-server start covers all of them and each variant has a link you can send someone.

**Divergence is the deliverable**, and it's the part that actually fails. Every variant must differ on a **structural axis — layout, information hierarchy, or interaction model — and must name the axis it takes.** Differing on color, spacing, or corner radius is a recolor, not a variant. Three variants of one idea is a failed prototype: you've spent the effort and still have nothing to choose between. Ship fewer than three only when three genuinely distinct axes can't be named, and then say so rather than padding the set.

Follow whatever routing and naming the project already uses, and **never invent a new top-level structure to hold a mock.**

When a UI skill is installed, borrow its anti-slop catalog and accessibility floor — but **override its design-system precedence for this job only, and say so out loud.** That precedence exists to enforce conformity, and conformity is the opposite of what a variant set is for. When no such skill is installed — the common case — the structural-axis test above stands on its own and is enough.

A winning variant is **evidence, not a starting point.** Building it for real is a fresh job against the real files, at full conformity, from scratch.

### 6. Write the verdict

Four lines, wherever it lands:

```
Question    — <what we needed to know>
Built       — <what was made, and which cases it was driven through>
Showed      — <what actually happened>
Answer      — <the decision this unblocks, now settled>
```

Write **Built** straight from the scope box, so it names the cases driven and transitions covered. That specificity is what makes the answer durable without keeping the code — it's what someone needs six weeks later when the decision gets relitigated.

Land it in whatever asked the question:

- **A plan document** — **strike the open question and add a row to its settled-decisions section**, citing the prototype. Don't leave an answered question sitting under "Open questions"; that misrepresents the plan's state to everything downstream that reads it. This is prototypekit's **one edit to a tracked file**, it's deliberate, and it only ever touches a file the user named.
- **An issue** — a comment.
- **Neither** — the chat.

**When the prototype answered a *different* question than the one asked, report and stop.** The verdict says the asked question is still open and reports the finding beside it. Chasing the new question mid-run is the exact drift the scope box exists to catch, wearing a justification — and the user may not want it chased at all. One carve-out: when the finding *invalidates the premise* of the asked question (the state model can't exist, so "does it hold up" is moot), that **is** the answer, and it's reported as one.

### 7. Park, then dispose

**Offer the park first**, as one ask, with the literal command — off by default, because the premise of this skill is that the answer matters and the code doesn't:

```sh
git checkout -b prototype-<slug> && git add -f <files> && git commit -m "prototype: <question>" && git checkout -
```

**Then delete, confirmed per file.** List every file you created this session and confirm each one individually. This is not ceremony: an excluded file is untracked, so git cannot recover it — the delete is final in a way most deletes aren't. **Never touch a file you didn't create in this session.**

Remove the exclude entry **only when every prototype file is gone.** Any file the user keeps gets reported by absolute path with its exclude line left in place — that's what keeps the leftover local-only and findable instead of quietly commit-able.

### 8. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed** — the files created, which were deleted and which the user chose to keep, whether the exclude entry was removed or retained, and whether the park happened.

**Where it landed** — the verdict's destination by path (the plan file and the row it added, the issue, or the chat), and the absolute path of anything still on disk.

**Next** — crown one move:

- The answer settles a plan decision → fold it forward with a planning or grilling skill, otherwise edit the plan directly.
- A UI variant won → build it for real with a UI skill, otherwise implement it from scratch at full conformity. **The mock is never promoted** — no copy of the prototype with the marker filed off.
- The answer settled a hard-to-reverse trade-off → record it as an ADR with a domain/decision skill, otherwise write the ADR by hand.

Name a sibling skill only when it's actually installed, and always give the plain fallback.

## Notes

- **Never unattended.** The deliverable is a human judgment, so a prototype run with nobody watching produces a deleted file and an answer nobody read. Keep it out of autonomous pipelines; per-file delete confirmation makes that structural rather than advisory.
- **Never promoted.** Folding a validated decision into the real code is a fresh build against the real files, with its own input and its own gate — never a rename of the prototype.
- **Touches no tracked file** except the one plan or issue the user named as the verdict's destination. The exclude entry is local-only by design.
- **Does not commit** (except the explicitly offered park), does not push, does not open a PR, does not file an issue, does not start a server.
- **Not a scratch-file manager.** It disposes of what it created this session, and nothing else.
- **Tools.** `allowed-tools` withholds web search and fetch, the mirror of how a research skill withholds the shell. prototypekit answers by building and cites nothing; if a question turns out to be settleable from documentation, that's a research job, and the missing tools make the boundary hold on hosts that honor the field.
- **No filesystem or shell** (e.g. a browser-based agent)? Print the prototype as fenced blocks with the paths they'd go to, skip the exclude and disposal steps entirely, and give the verdict inline — the disposal problem solves itself when nothing was written.
