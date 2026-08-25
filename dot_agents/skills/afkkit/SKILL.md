---
name: afkkit
description: >-
  Run a groomed `ready` GitHub issue through the whole build span unattended, covering worktree, implement, commit, review, fix, QA plan, and open PR, so one issue reaches a reviewable PR with no human at the keyboard. Use when the user says "run issue #N unattended" or "work the ready issues while I'm away". It starts from a groomed issue; planning and grooming stay attended.
license: MIT
allowed-tools: Bash, Read, Task, Agent, Skill
metadata:
  internal: false
---

# afkkit

The **away-from-keyboard** orchestrator. Hand it a groomed `ready` issue and it drives the middle of the dev workflow, the part that needs no human judgment once the issue is well-specified, from an isolated worktree to an open pull request: implement and commit, verify the acceptance criteria against the running code, review, fix, write a manual QA plan, open the PR, and flip the issue to `in-review`. The human gates stay where judgment lives: planning and grilling happen *before* (the `ready` label is the entry contract), review and merge happen *after*.

afkkit adds **no** worktree, tracker, or PR behavior of its own. It **sequences** companion kits (issuekit `start` at the very front, then implementkit, which commits its own work through commitkit, then reviewkit, qakit, and prkit) and owns exactly one thing they don't: the **escalation policy** that decides, at every step, whether to keep going or stop cleanly and leave the issue for a human. It is the autonomous sibling of statuskit: statuskit tells a human what to do next; afkkit does the next several things itself and stops at the boundary where a human is genuinely required.

## The contract

- **Input:** an issue number, or `all`. afkkit invokes **issuekit `start <n>`** itself to acquire the worktree, and issuekit refuses anything not labeled `ready`, gets the worktree from gitkit (off a freshly resolved base ref, adopting an existing one rather than recreating it), and flips `ready → in-progress`. That guard is the safety property, and it holds no matter who types the command: an issue only reaches `ready` after a human grill session (see the lifecycle below), and afkkit can neither promote an issue to `ready` nor start one that isn't (see [Start the issue](#1-start-the-issue)).
- **Output on success:** an open PR whose body carries the implementation's documented assumptions, what the acceptance checks confirmed, any unresolved review nits, and a pointer to a committed QA plan, plus the issue moved to `in-review`.
- **Output on a blocked run:** **no PR.** The worktree and its commits stay intact, a comment on the issue names the precise stuck-state, the issue is labeled for whoever must pick it up, and, in a batch, the next issue starts. afkkit never publishes half-broken work.

Everything between input and output is mechanical sequencing plus the escalation policy.

## When this fires

The user wants an issue taken through the build span without sitting through it:

- **one issue.** "afkkit 42", "run #42 unattended", "autopilot issue 42", "take #42 to a PR".
- **the whole ready queue.** "afkkit all", "work the ready issues while I'm away", "drain the ready backlog".

If they name neither an issue number nor `all`, ask which. afkkit never plans, grills, merges, or responds to PR review feedback, because those are human or out-of-scope (see [Non-goals](#non-goals)).

## Preflight (once per invocation)

Before touching anything, confirm the tooling and the conductor:

```sh
gh --version && gh auth status                          # GitHub CLI installed + authenticated
gh repo view --json nameWithOwner -q .nameWithOwner     # inside a repo on GitHub
```

- If `gh` is missing or unauthenticated, stop and point to `https://cli.github.com` / `gh auth login`. Don't work around it.
- **Companion-kit check.** afkkit is glue: it needs implementkit, commitkit, reviewkit, qakit, and prkit to do the actual work. Check which are installed. If a kit a step needs is absent, **stop and name it** rather than improvising its job badly, because an orchestrator missing its steps degrades by refusing clearly, not by half-doing the work. (Each step below also names the plain `gh` fallback where the action is trivial enough to run directly.) [Verify](#4-verify) is the one step that invokes no companion, since it runs the gate's own check list, so a missing kit never blocks it.
- **issuekit is required, and has no fallback.** It owns the `ready` guard afkkit's whole safety property rests on (see [Start the issue](#1-start-the-issue)). If it isn't installed, **refuse the run and say to install it**, and do not reach for `gh` and re-implement the guard. This is the one companion afkkit will not degrade around, because a second copy of a gate is a gate that can drift open, and the copy inside an unattended orchestrator is exactly the one nobody would notice drifting.
- **A GitHub tracker is required too, and that is a separate check.** afkkit runs on a `ready` label, so a project that tracks its work in Linear, Jira, a file, or nobody's system at all cannot run afkkit even with every companion kit installed. When the repo keeps no GitHub issues, **refuse and name that as the reason**: say the run needs work filed as GitHub issues and labelled `ready`, and point at **issuekit** `create` to file the plan first. Say it plainly rather than as a missing-dependency error, which sends the user off to install a kit they already have.
- **No shell / CLI available** (e.g. a browser-based agent)? You can't run `gh`, git, or spawn subagents. Say so and stop, because afkkit is an execution orchestrator and there's nothing to reason out in prose. Point the user at running the individual kits interactively instead.

## How the conductor runs each step

afkkit runs as a **conductor session**: the session you invoke it in sequences the pipeline, and each heavy step runs as a **subagent** dispatched to work inside the issue's worktree. This keeps the conductor's context small (the bulk of the tokens live in the subagents) and lets each step run on the model that fits it.

- **Dispatch a subagent per step** with the host's subagent tool, whether `Task` or `Agent`, whichever the harness exposes (agent type `general-purpose`), passing it four things: the **worktree path** that [Start the issue](#1-start-the-issue) returned for *this* issue, the **run directory path** and the files in it this step reads (see [The run directory](#the-run-directory)), the **companion skill to invoke** for that step, and the **model** from the table below. The subagent's first action is to work inside that worktree path (operate on its absolute paths, or `cd` into it); its second is to read the run-directory files it was handed.
- **The worktree path is carried run state, not the conductor's location.** The conductor's own working directory is irrelevant and never changes, since it holds each issue's path and dispatches into it. That's what lets one conductor session walk a batch of issues, each in its own worktree, without ever being inside any of them.
- **A dispatch has a floor.** Every subagent pays a fixed cost before it does any work (spawn, read its orientation, report back) and pays it again whether the step takes 175 tool uses or six. So **a step that needs nothing but the previous agent's context should not get its own dispatch.** That agent is already holding the diff, the gate result, and the file it just wrote; a fresh one has to rediscover all of it from cold to reach the same place. This is the rule that folds the commit into [Implement](#3-implement) and the fix rounds, and it is the test any new step has to pass before it earns a dispatch of its own.
- **Each subagent returns a small structured result** the conductor acts on: pass/fail, plus the identifiers and one-line summaries the conductor needs to decide the next move. **The payload itself goes in a file, not in the return**; see [The run directory](#the-run-directory) for which step writes what. The conductor holds the thread; the subagents hold the work.
- **The conductor redistributes payloads; it never re-derives them.** Holding a result is only half the job, because a later step usually needs it, and the conductor is the only thing that has it. Pass it forward by *reference*: every payload class in this pipeline has a file, so the reference is always a path plus the identifiers that matter (`apply B1, B3, N2 from .afkkit/findings-r1.md`). Pass by value only for the handful of one-line summaries the escalation comment needs. **Never re-type a fact a subagent already wrote down**, and never reconstruct one the conductor never received. Re-typing a review's findings into the next prompt costs the conductor's context twice and gains nothing the path did not already carry.
- **What the conductor may do, and may not.** It **dispatches** subagents, **redistributes** their payloads, **reads** the workspace to verify a claim ([the escalation contract](#the-escalation-contract) names the one case that requires it), and **decides** the next move: continue, loop, or escalate. That decision is the escalation policy, the one thing afkkit owns. It **never writes to the workspace**: no editing code, no running a build, no staging, no committing. *Read yes, write no* is a boundary that holds without a list of exceptions, and every step that once needed one has been dispatched elsewhere instead.
- **No subagent capability?** Degrade to running the steps inline in sequence in the conductor session. You lose per-step model routing (everything runs on the conductor's model) but the pipeline and escalation policy are unchanged. Say you're running inline.
- **Task-tracking tools are not run state.** If the harness offers a task list, using it as a progress display is fine, but it is not durable and has been observed to empty itself mid-pipeline. The pipeline below is the tracker; the issue's labels and comments are the record. Never let a step's status live only in a task tool.

## The run directory

Every step after the spec gate needs the same handful of repo facts: the test/build commands and what they chain, where the build output lands, the file that establishes the pattern being followed, what a related issue already landed. The gate discovers all of it. Without somewhere to put it, that discovery is thrown away and each later step re-derives it from cold, which is the single most expensive habit in this pipeline: every tool use re-bills the agent's whole accumulated context, so a rediscovery costs far more than the fact is worth.

The same argument covers every other payload the run produces. A review's findings, the gate's assumptions, what the checks actually returned: each of them gets re-typed into the next prompt by hand if it has nowhere to live, which bills the conductor for text a subagent already wrote out once.

So each step writes its payload down once, in one place, and every later step reads the path.

- **Where.** `.afkkit/` at the **worktree root**, excluded from git so nothing in it reaches the PR diff, because a reviewer should not see the agents' working notes. Register the directory in the repo's private exclude file, which is local-only and leaves the tracked `.gitignore` untouched:

  ```sh
  git -C <worktree> rev-parse --git-path info/exclude    # resolve the real path first
  ```

  **Ask git for that path; never hardcode `.git/info/exclude`.** In a linked worktree, which is the only kind afkkit ever works in, `.git` is a *file* pointing elsewhere, not a directory, so the literal path doesn't exist. Append `.afkkit/` only if it isn't already listed; the exclude file is shared across the repo's worktrees, so a batch would otherwise add the same line once per issue. One directory means one exclude line, no matter how many payloads the run writes.

- **What's in it.**

  | File | Written by | Read by |
  |------|-----------|---------|
  | `orientation.md` | [spec gate](#2-spec-gate) | every later step |
  | `assumptions.md` | [spec gate](#2-spec-gate) | [Open the PR](#8-open-the-pr) |
  | `checks.md` | [spec gate](#2-spec-gate) | [Verify](#4-verify), [QA plan](#7-qa-plan) |
  | `verified.md` | [Verify](#4-verify), refreshed by [QA plan](#7-qa-plan) | [Review](#5-review), [QA plan](#7-qa-plan) |
  | `findings-r<N>.md` | [Review](#5-review) round N | [Fix loop](#6-fix-loop) round N |

- **What goes in `orientation.md`.** Facts, each with its source: the gate command and its result, paths that exist, the symbol or config that governs the behavior being changed, the issue's acceptance criteria restated concretely. **Never conclusions**, because "the auth flow is fine" is not a fact, where "`src/auth/session.ts:40` sets the cookie `maxAge` from `SESSION_TTL`" is.
- **What it is not.** Not a plan, not a design, not a substitute for the issue body. If `orientation.md` grows past roughly a page, the gate is writing an essay instead of an index.
- **Findings carry stable identifiers.** A review writes `B1`, `B2` for blockers and `N1`, `N2` for nits, and keeps them stable for the rest of the run. That is what lets a fix round be dispatched with `apply B1, B3, N2 from .afkkit/findings-r1.md` instead of a paragraph of re-quoted evidence.
- **Trade-off, stated plainly.** Every downstream step now inherits the gate's understanding instead of re-deriving it, so a *wrong* orientation propagates silently to the end of the run. A wrong entry in `checks.md` propagates the same way. That is the price of not paying for the same discovery five times, and it is why the gate stays on the strongest tier and why both files carry facts-with-sources rather than judgments: a wrong path is caught the moment a step opens it, a wrong conclusion is not.
- **No writable filesystem?** Fall back to the conductor holding each payload and pasting it into the dispatch prompts that need it, and say that's what you're doing. The pipeline is unchanged; only the delivery mechanism is.

## Model routing

Default per-step models. Two things drive each assignment: **what a mistake costs**, since a missed decision at the spec gate poisons every step after it while a clumsy commit message is cosmetic, and **what the step costs to run**, which is not what most people expect.

**How a step's cost actually works.** Every tool use re-bills the agent's entire accumulated context. So cost tracks **context size × turns**, not token volume and not how often the step fires. A measured run bears this out sharply: the two steps that *explored the codebase*, each running exactly once, were over 40% of the bill between them, while three mechanical commit dispatches were under 9% for work the previous agent could have done in a handful of turns. **The way to make a step cheap is to hand it what it needs, not to ask it to think less**, and the cheapest step of all is the one that never gets its own dispatch. That is what [the run directory](#the-run-directory) and the dispatch floor are for, and it is why an expensive step is more often fixed by deleting a rediscovery than by dropping a tier.

The **Tool uses** column is a descriptive baseline from observed runs, never a target, so read it as "this is roughly what this step needed." Where two runs disagreed the column gives the range. Implement is the row that does not generalize: it scales with the size of the change, it runs [once per phase](#one-dispatch-per-phase), and a run outside the range is not evidence that anything went wrong. [The run metrics](#run-metrics) in the hand-off are what keep this column honest, because they come from real runs rather than one remembered one.

| Step | Model | Runs | Tool uses | Why |
|------|-------|------|-----------|-----|
| Spec gate | `opus` | 1× | ~29–31 | Gates the whole run, since a missed decision-gap poisons every step after it, and every later step inherits its orientation and its check list. Runs once, so buying capability here is nearly free. |
| Implement | `opus` | 1× per phase | ~45–175 per phase, scales with the change | The bulk of the work; implementkit's own test + build gate is the safety net underneath it. It commits its own work before returning. |
| Verify | `opus` | 1× | ~20–30 | Runs the code rather than reading it, the one lens review does not have. Small context (orientation plus the check list), so the strong tier is cheap here. |
| Review, round 1 | `fable` | 1× | ~15–16 | The quality gate, over the full branch diff, deliberately on a **different model family** from the one that wrote the code; see below. |
| Review, rounds 2–3 | `fable` | ≤2× | ~10–12 | Same model, delta-scoped to the fix commits (see [Fix loop](#6-fix-loop)). |
| Fix | `opus` | ≤2× | ~26–43 | Applying review findings against a concrete list. It commits its own work before returning. |
| QA plan | `opus` | 1× | ~35 | Grounded generation from the diff, against a gate that is already green and a check list that has already run. |
| PR | `opus` | 1× | ~12–13 | Title and body from the real commits, plus the payload paths handed in. |

**Commit has no row, on purpose.** It used to run as its own `haiku` dispatch and it is now folded into Implement and each fix round, which run it on their own tier. That is the dispatch floor applied: a standalone commit agent has to re-read a diff the previous agent authored minutes earlier, and in the measured run three of them spent 92,839 tokens and 55 tool uses doing exactly that. **The trade is real and worth naming:** the commit now runs inside a large context instead of a fresh cheap one, so the saving is the removed rediscovery and the three dispatch latencies, not the whole 92,839. [The run metrics](#run-metrics) are what settle whether it held.

The consequence is that **no step routes to `haiku` any more.** The arithmetic below still holds; the table simply has no mechanical-enough step left to spend it on.

**Why review runs on a different family, not a "better" one.** The reviewer's job is to catch what the implementer got wrong, and an implementer and reviewer from the same model family share blind spots by construction. Routing review to `fable` buys *independence*, and the observed behavior is exactly what that's for: the review re-derived claims against the actual files rather than trusting the conductor's prompt about them. **It is not the cheap option**, since `fable` ran roughly 4× `opus`'s cost per token in the measured run, making review ~16% of the bill on ~5% of the tokens. That is a deliberate purchase of a second opinion on the quality gate, priced here so nobody mistakes it for a saving.

The same arithmetic runs the other way and is worth stating outright: **moving a step *down* to `fable` would raise its cost, not lower it.** The cheap tier is `haiku`.

**Verify does not get `fable`, even though independence is its point.** The tier is bought for review specifically, and it bills roughly 4× per token. A fresh `opus` agent already has no memory of writing the code, which is the property Verify needs: it reads a check list somebody else wrote and runs commands. Paying the independence premium twice buys very little and costs a lot.

Write the **alias** (`opus`, `fable`, `haiku`), never a pinned model ID, because an alias follows its tier as the tier moves and a pinned ID rots.

**State the deliberation budget in the prompt, but only where exploring is the waste.** Don't lean on harness knobs to make a cheap step cheap; dispatch parameters vary by host and change between releases. Say it in the subagent's prompt instead: "this is a mechanical step: read the run-directory files and the diff, produce the output, don't go exploring the codebase." Apply that nudge to **QA and PR**, the steps where orientation and an already-green gate have removed the reason to explore.

**Never budget Implement, the spec gate, or Verify's probe.** Implement needed 175 tool uses in the measured run because the work needed 175, and the gate's exploration is the thing every later step depends on. Verify's probe is capped by count rather than by budget for the same reason: it is the only step that exercises live behavior, and the three defects it caught in the measured run came from probing past the written list. Nudging any of the three toward a smaller number buys cheaper, worse output, the one trade this pipeline should never make. Treat every budget line as a nudge the subagent follows, not a floor the harness enforces.

**Inline override.** The user can override any step's model at invocation in plain language: "afkkit 42, implement on opus", "afkkit all, review on fable". Honor the override for the named step(s); everything else keeps the table. There is no config file, so the table plus the spoken override is the whole routing surface.

## The pipeline (per issue)

Run these in order for each issue. Any step that can't proceed hands to [the escalation contract](#the-escalation-contract) and the issue stops there, cleanly, with no PR.

### 1. Start the issue

Dispatch a subagent to invoke **issuekit** `start <n>` and return the worktree. afkkit adds nothing to it and re-implements none of it: issuekit refuses any issue not labeled `ready`, asks **gitkit** for the worktree (branch `issue-<n>-<slug>`, cut from the resolved base ref, adopting an existing one rather than recreating it), and flips the label `ready → in-progress`.

**Dispatch it on the conductor's own model, not the cheap tier.** This step is the only place the `ready` guard becomes legible to afkkit, and its result is not a boolean: issuekit can refuse four distinguishable ways, each routing somewhere different, and one of them isn't a refusal at all. A relay that flattens that distinction breaks the escalation policy silently. The subagent returns either `{worktree, branch, label}` or a structured refusal naming **which** of the cases below it hit, verbatim.

Dispatching rather than running inline is deliberate: issuekit and gitkit are large documents, and running `start` in the conductor pins both into the conductor's context for the rest of the run, re-billed on every turn, for every issue in a batch. The conductor needs the returned *path*, not the machinery that produced it.

**Say the run is unattended when you invoke it.** issuekit previews every mutation and waits for an OK. It carves out exactly one exemption, and that exemption is the mode's rather than the caller's: `start`'s `ready → in-progress` flip runs unprompted for anyone, so afkkit inherits it without asking. Saying the run is unattended still matters, because it tells every later step there's nobody to answer a prompt. One other mutation in this pipeline carries the same kind of mode-owned exemption ([prkit's `in-review` advance](#8-open-the-pr)); nothing beyond those two is exempt, and afkkit never asks for a broader one.

Then verify what came back rather than taking it on faith. The conductor runs these itself, since reading the workspace is squarely inside its boundary:

```sh
git -C <worktree> rev-parse --show-toplevel              # the returned path is a real worktree
git -C <worktree> branch --show-current                  # the issue's branch is checked out there
gh issue view <n> --json labels -q '.labels[].name'      # now reads in-progress
```

Hold that path as this issue's run state; every subagent below is dispatched into it.

**If issuekit refuses, that's a preflight stop, not [an escalation](#the-escalation-contract)**, because nothing has happened yet, so there's no comment and no label churn. Report the reason issuekit gave and, in a batch, move to the next issue:

- **`needs-planning`** → the decisions aren't settled; it needs a human grill session first.
- **`blocked`** → name the `Blocked by #N` prerequisite and its state.
- **closed, or carrying no lifecycle label** → say which; issuekit `triage` is what classifies it.

An issue already `in-progress` is **not** a refusal. issuekit takes its adopt path, gitkit hands back the existing worktree, the label is left alone, and afkkit continues. That covers both the re-run path (an issue escalated to `needs-planning`, grilled back to `ready`, and re-run) and a worktree a human staged by hand, on the same code path as a first run rather than as a special case.

### 2. Spec gate

Dispatch a subagent (worktree) to read the issue body and the relevant code, and classify any gaps between what the issue specifies and what building it requires. Because it is the only step that explores the repo before any code exists, it is also the step that writes down everything the run will need later. It has **five outputs**: the classification below, the issue's phase list, plus `orientation.md`, `assumptions.md`, and `checks.md` in [the run directory](#the-run-directory). Writing all three files costs the gate almost nothing; it is already holding everything that goes in them.

**The phase list is a return value, not a file.** An issue written by issuekit carries its phases as `## Phase N` headings, and [Implement](#3-implement) dispatches one subagent per heading. The gate reads the whole body anyway, so it returns the headings in order and the conductor holds them. A body with no phase headings returns a single unnamed phase, which is the same thing as today's one dispatch.

The classification is the whole point:

- **Missing decisions.** Product choices or trade-offs a human would have to make (which behavior is correct, which of two designs, an unstated requirement). These are exactly what a grill session settles. → **Escalate as a planning gap:** stop before writing any code, since this is the cheapest possible failure point. Comment the exact open questions on the issue (phrased as the grill-questions a human should answer), and flip the label `in-progress → needs-planning` so the issue lands in the human's planning queue. Move to the next issue.
- **Missing mechanics only.** File names, minor edge cases, naming, small ambiguities a competent implementer fills uncontroversially. → **Proceed.** The gate writes every mechanical choice it's making to `assumptions.md`, and returns the count. [Open the PR](#8-open-the-pr) gets the path, so the reviewer sees exactly what was assumed without the conductor re-typing any of it.

A `ready` issue *should* clear this gate, because grilling is what earns `ready`. The gate is the backstop for a decision that slipped through, and routing it to `needs-planning` rather than guessing is the design's core stance: never build on an un-made decision.

**The gate also writes the check list.** `checks.md` holds one entry per acceptance criterion: an identifier, the **observable** that would confirm it, a **provisional command** that should produce that observable, and a flag for whether an agent can confirm it or only a human can. [Verify](#4-verify) runs the agent-confirmable entries; the human-only ones become manual cases in [the QA plan](#7-qa-plan).

The gate is the right author for two reasons, and the second is the one that matters:

- It already restates the acceptance criteria concretely for `orientation.md`, so the marginal cost is a few lines.
- **It runs before any code exists**, so the checks cannot be shaped around the implementation. A check list written after the fact tests what the code does; a check list written from the issue tests what the issue asked for. That is a test-first property this pipeline gets for free from a step it was already paying for.

The command is *provisional* on purpose, because the gate is guessing at an invocation that doesn't exist yet. Verify adapts it to what actually shipped and records what it really ran. Write the observable precisely and the command approximately, never the other way round.

### 3. Implement

Dispatch a subagent (worktree) to invoke **implementkit** against the issue spec. implementkit resolves its own straight-through-vs-TDD mode and enforces the repo's own test + build gate before it reports done, and afkkit doesn't second-guess that. Two failure shapes route differently:

- implementkit **bounces the spec as too thin**, meaning it hit a genuine *decision* gap the [spec gate](#2-spec-gate) missed. Treat it as a planning gap: escalate to `needs-planning` with the specific gap commented.
- implementkit **can't get the gate green** after its own bounded fixes, which is an *execution* failure, not a spec problem. Escalate keeping `in-progress`, with the failing gate output commented.

**Then the same subagent commits, before it returns.** Once implementkit reports green, that agent invokes **commitkit**, which groups the changes and writes Conventional-Commits messages from the diff. This banks the implementation before review. If commitkit isn't installed, the fallback is a single `git add -A && git commit` with a conventional subject derived from the issue title.

Say so in the dispatch prompt, because the agent has to know the commit is part of its job: implementkit's own contract stops short of committing and it will otherwise hand back an uncommitted tree.

Folding rather than dispatching is [the dispatch floor](#how-the-conductor-runs-each-step) applied to the clearest case in the pipeline. The agent that wrote the diff is still holding it, so the commit costs it a handful of turns. A fresh agent has to re-read the whole diff from cold to reach the same place, and in the measured run three of them spent 92,839 tokens and 55 tool uses doing precisely that.

#### One dispatch per phase

**A multi-phase issue gets one implement dispatch per phase**, in the order the phases are written, each invoking implementkit narrowed to that phase and each committing before it returns. A single-phase issue gets exactly one dispatch, which is this step's original shape and its original cost. The phase list comes from the [spec gate](#2-spec-gate), which read the whole issue body already; the conductor holds it and never re-reads the issue to rebuild it.

The loop is what makes a large issue workable. Issues are now sized to a whole plan rather than to what fits in one agent's context, so one dispatch for a four-phase issue would ask a single agent to carry every earlier phase's exploration while it writes the last one.

**This is [the dispatch floor](#how-the-conductor-runs-each-step) read the other way, and the two rulings are consistent.** The floor removes a dispatch when the next step needs *the previous agent's context*, which is why the commit stays folded in. It keeps a dispatch when the next step needs the *repository state* the previous agent produced and none of the reasoning that produced it. Phase N+1 needs phase N's committed code, not its transcript, so a fresh agent starts from a clean tree and the branch carries the hand-off.

Route a failure exactly as a single-phase run does, per phase. Then name the phase in what the conductor holds:

- **A phase escalates** → the run stops at that phase. The escalation comment names the phases already committed, the phase that stopped, and why, so a re-run resumes at the right place instead of rebuilding what landed.
- **A phase reports green** → its commits are on the branch. Dispatch the next phase.

**Every step after this one still runs once**, over the whole branch diff: [Verify](#4-verify), [Review](#5-review), [the fix loop](#6-fix-loop), [the QA plan](#7-qa-plan), and [the PR](#8-open-the-pr). The loop is Implement's alone. Reviewing per phase would re-read a growing diff once per phase and split the reviewer's judgment across pieces it cannot see whole, which is the opposite of what the review tier is bought for.

**The conductor does not tick the issue's phase checkboxes as phases land.** It would read as useful progress on a long run, and it is a new unprompted tracker mutation that no mode owns. This pipeline has exactly two such exemptions ([issuekit `start`'s flip](#1-start-the-issue) and [prkit's `in-review` advance](#8-open-the-pr)), both belonging to the mode rather than to afkkit, and a progress indicator does not earn a third. The commits on the branch are the record while the run is live, and the PR is the record after it.

### 4. Verify

Dispatch a subagent (worktree) to run the check list the [spec gate](#2-spec-gate) wrote, against code that is now green and committed. **This is the only step that runs the code rather than reading it**, and that is the whole reason it exists: in the measured run, live verification caught three defects both review rounds missed, but it ran last, so nothing it learned could reach the fix loop. Here it runs while a fix is still cheap.

Hand it the worktree, `checks.md`, `orientation.md`, the fact that implementkit's gate is already green, and where the build output lands. Its job, in order:

1. **Run every agent-confirmable check in `checks.md`.** Adapt each provisional command to what actually shipped, and record the command it really ran, not the one the gate guessed.
2. **Probe past the list, at most six times.** Error paths, degraded or missing inputs, the stdout/stderr split, an absent prerequisite. This is where the measured run's three surprise findings came from, and a strict list-executor would not have found any of them.
3. **Write `verified.md`** to [the run directory](#the-run-directory): ✅ or ❌ per check, the real output, the exact commands, and an explicit list of **what it did not check**. If it stopped at the probe cap, it says what it left unprobed. A capped step that reports full coverage is worse than one that never ran.

Three hard rules, all of them about not re-doing paid work: **never edit code**, because a failure is evidence for [Review](#5-review), not something this step fixes; **never rebuild** unless the change under test *is* the build path; **never re-derive** a fact `orientation.md` already holds.

It returns pass/fail counts and the failed check IDs, one line each.

**A ❌ is evidence, not an escalation.** [Review](#5-review) reads `verified.md` and ranks the failure through reviewkit's own requirement-completeness pass, so afkkit adds no second classifier for severity; the one it already has is enough. The exception is total: if the change **does not run at all**, that is an execution gap. Escalate keeping `in-progress` and don't pay for a review of code that can't start.

### 5. Review

Dispatch a subagent (worktree) to invoke **reviewkit** against the branch diff, handing it `verified.md` alongside. reviewkit returns severity-ranked findings across its passes. The conductor splits them into **blockers** (correctness, completeness, security, which must be fixed) and **nits** (polish, style, fix once, don't gate on). This split drives the fix loop.

**Tell it to write the findings to `.afkkit/findings-r<N>.md`, not to `docs/reviews/`.** reviewkit offers to save a durable report under `docs/reviews/`; taking that offer here would put the agents' working notes in the PR diff. The run directory is excluded from git, which is where they belong. Findings carry stable IDs so the fix round can be dispatched against them by reference. The subagent returns only the verdict, the blocker IDs with one line each, and the nit IDs, because the conductor needs those one-liners for an escalation comment and needs nothing else.

**Tell the subagent it is the fresh reviewer.** reviewkit's own rule is to hand its passes to a fresh subagent rather than self-review code it just wrote, but this dispatch has *already* satisfied that: the agent has no memory of the implementation and is reading the diff cold. Say so in the prompt, and say it must run the passes itself. Otherwise it delegates again, and a second agent re-reads the entire branch diff to reach the same place, the most expensive redundant hop this pipeline can make.

### 6. Fix loop

Bounded at **two fix rounds**. Per round:

1. Dispatch a subagent (worktree) to invoke **implementkit** with a **fix round**, dispatched by reference: the path to `findings-r<N>.md` and the IDs to apply. Never re-type the findings into the prompt, because the reviewer already wrote them out with their evidence, and re-quoting them bills the conductor for text that is already on disk.
2. **The same subagent commits its fixes before returning**, through commitkit, exactly as [Implement](#3-implement) does and for the same reason.
3. Re-review (**reviewkit**), **delta-scoped**: point it at the fix commits and the surviving blocker IDs, not the whole branch diff again. Round 1 already covered the untouched code, and re-reading all of it is the most expensive thing this pipeline can do. Only re-review while **blockers** remain.

**The nit sweep happens exactly once, in round 1.** Round 1's input is every surviving blocker **plus every cheap, concrete nit** review round 1 raised: a wrong ARIA attribute, a misleading doc line, a leaked handler. Those cost almost nothing to fix while an agent is already in the file, and they become someone's afternoon later. Nits too big for the sweep go to the PR body as "known follow-ups" instead.

**A delta re-review's nits never earn a round of their own.** They go straight to the PR body as known follow-ups, whatever they are. The nit sweep already happened; a second one buys a cosmetic change at the price of two dispatches. In the measured run that cost 50,252 tokens and 1m32s to turn one `log.warn` into a `log.info`. This also makes the loop's termination unconditional, because only a blocker can extend it.

Note what this does *not* do: it does not let the reviewer apply its own fixes. reviewkit is read-only by contract, and afkkit does not override a companion's rules from the outside (see [Non-goals](#non-goals)). Moving the nit earlier is cheaper than moving the fix into the reviewer, and it costs no contract.

Stop the loop when no blockers survive. If blockers still survive after the second round, or a fix round can't get the gate green, **escalate keeping `in-progress`**, comment the surviving blockers (or the red gate), and move on. No PR opens with known blockers in it.

### 7. QA plan

Dispatch a subagent (worktree) to invoke **qakit**, which writes a manual QA plan grounded in the diff to `docs/qa/qa-<slug>-YYYY-MM-DD.md` and fills its **Automated verification** section from checks it has run.

**By the time this runs, most of that work is done.** Hand it `checks.md`, `verified.md`, `orientation.md`, the fact that the gate is green, and where the build output lands. It re-runs the recorded checks against the final code, since the fix loop has moved since [Verify](#4-verify) ran, and transcribes the outcomes. **It does not design a check set from scratch**, and it does not re-derive the acceptance criteria: the gate already wrote them down and Verify already exercised them. The human-only entries the gate flagged in `checks.md` are the manual test cases, which is qakit's own split arriving pre-made.

**Never rebuild.** This is a rule, not a caution. QA needs built artifacts to *inspect*; it does not need to produce them. In the measured run this step destroyed and rescaffolded a build [Implement](#3-implement) had produced ten minutes earlier, which made QA the second-costliest step in the pipeline for no new information. The single exception: the change under test **is** the build or scaffold path.

Leave the doc uncommitted. [Open the PR](#8-open-the-pr) commits it on its way past, because it already has the path, and spawning a whole subagent to commit one file the previous step just wrote is exactly the rediscovery this pipeline is built to avoid.

### 8. Open the PR

Dispatch a subagent (worktree) to invoke **prkit**, handing it paths rather than prose: `assumptions.md` from the [spec gate](#2-spec-gate), the `findings-r<N>.md` files plus the IDs of the **unresolved nits** carried from the fix loop, `verified.md` for what the checks actually confirmed, any **unmet acceptance criteria** surfaced by [the escalation contract](#the-escalation-contract), and the **QA-plan path**, which prkit commits before it pushes, since the doc must travel with the branch and prkit is already the step that touches git. prkit writes the title and body from the real commits and diff, pushes the branch, opens the PR, and advances the linked issue to `in-review`. **That advance runs unprompted**, under prkit's own mode-owned exemption, so it does not stall an unattended run: it accepts an issue at `in-progress` or `ready` and refuses every other lifecycle state, which is the same pair issuekit `start` guarantees at the front of this pipeline. afkkit relies on prkit for the flip rather than duplicating it; only if prkit is absent does the conductor fall back to `gh issue edit <n> --remove-label in-progress --add-label in-review` after opening the PR by hand.

Everything in that list is a file the run already wrote. The conductor hands over paths and identifiers; it does not restate the assumptions, re-quote the findings, or summarize the QA result. In the measured run, re-typing those payloads by hand cost roughly 1,500 words in this step alone.

This is the successful terminus: an open PR, a QA plan, and an `in-review` issue.

### 9. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Nobody watched this run, so the report *is* the handover: a human is reading it cold, after the fact, to work out what they now have to do.

**What changed.** Give one outcome line for the issue: **opened** (PR link), **escalated** (which label, one-line reason, issue link), or **skipped** (issuekit refused it at [Start the issue](#1-start-the-issue), with the reason, and the fact that nothing was mutated). In a batch, accumulate these; the batch summary is emitted at the end (see [Batch mode](#batch-mode-all)).

**Where it landed.** Give the worktree path and branch, which survive both an open PR and an escalation. On an escalation this is load-bearing: the commits are real work sitting on disk, and a human who doesn't know where they are will start over. A skipped issue has no worktree, so say that plainly rather than printing a path that doesn't exist.

**Next.** Route by outcome, naming a sibling kit only when it's installed and otherwise describing the action plainly:

- **opened** → the PR needs a human reviewer, which is exactly where afkkit's span ends. **mergekit `start <n>`** pulls it down into the worktree it was built in, syncs it, and prints the review pack; the QA plan committed in [QA plan](#7-qa-plan) is what they run by hand.
- **escalated to `needs-planning`** → a decision is missing, so the move is a grill session with **grillkit** on the issue's open questions, then re-run afkkit once it's back to `ready`. Don't suggest re-running afkkit as-is; it will stop at the same wall.
- **escalated, still `in-progress`** → execution is stuck, not the spec. Point at the commented gate output or surviving blockers and name the plain action: pick it up in the existing worktree by hand.

Crown **one** next move even after a batch, usually the oldest open PR, since review is the bottleneck a returning human clears first. Route, don't launch: afkkit never invokes mergekit or grillkit itself, because both want a human in front of them.

### Run metrics

Print one table per issue, after the outcome and before the next move. One row per dispatched step, so [a per-phase implement dispatch](#one-dispatch-per-phase) gets its own row and names the phase (`Implement · phase 2`):

| Step | Model | Time | Tool uses | Tokens |
|------|-------|------|-----------|--------|

The conductor fills this from what each dispatch reports back, and it measures nothing itself and runs no extra call to find out. **Print only the columns the harness actually gives you.** If a host reports no token count, drop that column and say the host doesn't report it. Never estimate a number into it; a made-up figure here is worse than a missing one, because the whole point of the table is to correct [the routing table](#model-routing) from real data instead of one remembered run.

In a batch, print a table per issue plus a total row for the run.

**No file.** The metrics live in this report and nowhere else. Writing them to disk would put the conductor inside the workspace, which [its boundary](#how-the-conductor-runs-each-step) rules out, and afkkit deliberately writes no run-report artifact.

## The escalation contract

The one policy afkkit owns. Whenever a step can't proceed, **escalate** rather than push forward.

**First, verify a "pre-existing" claim before accepting it.** A step that reports a gate as red-but-already-broken is asking to be excused from the one check that stands between an unattended run and a shipped regression, and it is the single easiest thing for a subagent to get wrong, because a failure it caused and a failure it inherited look identical from inside the worktree. The conductor re-runs that command against the **base branch** and only then accepts the claim. This is a *read* of the workspace, which is inside the conductor's boundary; it does not fix anything, and it never turns into an edit.

Two outcomes, both concrete:

- **The base is green too.** The failure belongs to this branch. Treat it as an execution gap and escalate on it; do not let the step wave it through.
- **The base is red as well.** The claim holds, and the run continues. But if the failure means an **acceptance criterion cannot be met from repo state**, that goes into the PR body as an explicit unmet criterion, handed to [Open the PR](#8-open-the-pr) alongside the assumptions list. A criterion that quietly didn't happen is the one thing a reviewer cannot catch by reading the diff.

`verified.md` is the best source for that last judgment, because [Verify](#4-verify) records which acceptance criteria actually confirmed and which did not. Read it before deciding a criterion is unmet; don't infer it from a failing gate.

**A step that needs consent, with nobody to ask, escalates.** No prompt can be answered in an unattended run, so a dispatched step that reaches a preview-and-confirm gate must stop rather than wait or assume a yes. Treat it as an execution gap: keep `in-progress`, comment what the step was about to do, and move on. The exception is a mutation the owning skill exempts for **every** caller: issuekit `start`'s `ready → in-progress` flip and prkit's `in-review` advance are both exempt at the mode, so neither is a consent gate and neither stalls a run. afkkit relies on the exemptions the owning skill already wrote and never widens one.

Then escalation always means the same five things:

1. **No PR.** Never open a pull request from a run that hit a wall.
2. **Keep the work.** Leave the worktree and every commit intact, so the next human (or the re-run) picks up from real progress, not a clean slate.
3. **Comment the stuck-state** on the issue, precisely: the open questions for a planning gap, the failing gate output for an execution gap, the surviving blockers for a review gap. On a [multi-phase issue](#one-dispatch-per-phase), name the phases that committed and the phase that stopped, because a re-run that rebuilds landed work is the expensive way to fail twice.
4. **Set the label by *cause*.** This is the load-bearing distinction:
   - **Planning gap** (the [spec gate](#2-spec-gate) or implementkit found a missing *decision*) → flip `in-progress → needs-planning`. The spec itself is incomplete, so it goes back to the human's grill queue. A re-run after grilling adopts the existing worktree.
   - **Execution gap** (tests won't go green, or review blockers survive the fix loop) → **keep `in-progress`**. The spec was fine; execution is stuck. The comment and batch summary carry the detail for a human to unstick, with no label churn, because the issue isn't waiting on a *decision*.
5. **Continue the batch.** One escalated issue never sinks the run, because the next `ready` issue starts.

## Batch mode: `all`

`afkkit all` takes its queue straight from the tracker (`gh issue list --label ready --json number,title,labels,updatedAt`) and walks it **sequentially**, running the full pipeline from [Start the issue](#1-start-the-issue) onward on each.

**Order the queue by priority.** issuekit's priority labels (`critical`, `high`, `medium`, `low`, and unassessed) come back in that same `labels` array at no extra cost, and they decide the walk order: highest first, then oldest-updated within a level, then unassessed last. Ordering matters more here than anywhere else in the workflow, because an unattended batch is the one place nobody is watching to reorder it: a run that stops early after four of nine issues has silently *chosen* which four shipped, and priority is the only thing that makes that choice the user's rather than the tracker's arbitrary sort. Fall back to oldest-first when no issue in the queue carries a priority at all, and say so in the preview rather than implying a ranking that isn't there. An explicit order the user names in the prompt beats both.

**Priority orders the queue and relaxes nothing.** A `critical` issue goes first and is otherwise an ordinary run: it still needs `ready`, it still faces the [spec gate](#2-spec-gate), and it still escalates rather than guessing. Urgency is a reason to work something sooner, never a reason to work it with fewer checks, and an unattended agent is precisely where that distinction has to hold, since the human who declared the emergency isn't there to catch what a relaxed gate lets through.

**One confirmation, up front.** Print the queue it's about to drain (number, priority, and title per issue, in the order it will walk them) and wait for a single OK before starting anything. The human is by definition still at the keyboard the moment they type `afkkit all`, so this costs nothing, and it's the last chance to pull an issue that was promoted to `ready` too early. After that OK the run is unattended: no further prompts, whatever happens. A single-issue invocation (`afkkit 42`) needs no confirmation, because naming the number *is* the intent.

**The queue is fixed at the moment of that OK**, meaning the snapshot the human saw, not a live `gh issue list` re-read before each issue. The run mutates labels as it goes (`ready → in-progress`, and `→ needs-planning` on a planning escalation), so re-reading would drain issues nobody approved and could re-pick one the run itself just moved. Approve the list, work the list.

**Issues start just in time**, each at the top of its own pipeline run, never all up front. Two reasons, both about what a half-finished batch leaves behind: a worktree branches off a base ref fetched at the moment it's created rather than one that went stale waiting its turn in a queue, and a batch that stops early leaves the issues it never reached untouched in `ready` instead of flipped to `in-progress` with orphaned worktrees behind them.

**`all` drains `ready` only.** An issue already `in-progress` may have a human sitting in its worktree, so the batch passes over it; name it explicitly (`afkkit 42`) to include it, and issuekit's adopt path picks up the existing worktree. List any such issues in the up-front preview so it's clear what was left out and why.

**Sequential, not parallel, and the ceiling is worth stating rather than leaving it to read like an unexamined v1 limit.** Three things hold it there.

- **Most of the run cannot be parallelized at all.** [Implement](#3-implement) was 44% of the measured wall clock on its own, and it is irreducibly serial: nothing downstream of it can start before it finishes, and its phases build on one another in one branch, so the phase loop is serial for the same reason at a smaller scale. Even a perfect parallelization of every other step caps the saving near 55%, and that is the ceiling before any of the risks below.
- **The one genuinely independent pair is unsafe.** QA and review could run at the same time, and a QA plan written from a diff the fix loop then changes describes behavior that no longer exists. The pipeline already moved the live-verification half of that work earlier, to [Verify](#4-verify), which captures the useful part of the overlap without the staleness.
- **Concurrency across issues costs a human more than it saves.** Parallel branches off the same base make merge-conflict and resource behavior unpredictable, and a returning human faces a pile of concurrent PRs rather than one at a time.

Each issue is independent, so an escalation is logged and the walk continues to the next, in the approved priority order.

**Drop each issue's payloads once it terminates.** The moment a PR opens (or the issue escalates), everything the conductor was carrying for it (the run-directory paths, the finding IDs, the metrics table once it's printed) has done its job. Keep the one-line outcome for the batch summary and let the rest go. One conductor session walks the whole queue, and its context is re-read on every turn it takes; a batch that accumulates ten issues' worth of payloads pays for the first issue's findings while working the tenth. With [the run directory](#the-run-directory) in play every payload is already just a path, which is most of this problem solved before it starts, because a batch only has to drop paths, not paragraphs.

At the end, print the **batch summary**: how many PRs opened (with links), how many escalated and to which state (`needs-planning` versus still `in-progress`, with links and one-line reasons), how many were skipped before starting and why, and, when the run didn't reach the end of the queue, **which issues it never got to, with their priorities**, so a returning human sees immediately whether the unfinished tail was the cheap end of the list or the expensive one. Then give the single crowned next move from [Hand off](#9-hand-off). That summary plus GitHub's own PR notifications is the whole signal surface, because afkkit writes no run-report artifact and sends no push notifications. Success is the PR itself; a blocked issue is a comment and a label the human sees on return.

## Non-goals

afkkit is deliberately narrow, covering the middle of the workflow and nothing else:

- **No planning or grilling.** It never invents product decisions; a thin spec goes back to the human queue as `needs-planning`. plankit and grillkit stay interactive and out of the unattended path.
- **No PR-feedback loop, no merge, no teardown.** The span ends at PR open. Responding to a human's review comments is a designed-for *later phase*, not v1. Merging is a human gate. The land-side reconciliation, meaning issuekit `close` (close the issue, unblock dependents, remove the worktree via gitkit), runs *after* merge, also out of span.
- **No parallel batches, no browser verification, no notifications** in v1: issues run sequentially, verification is qakit's manual plan rather than verifykit's browser capture, and GitHub plus the session summary are the only signal.
- **No new worktree, tracker, or PR logic.** gitkit owns the worktree lifecycle and the base ref; issuekit owns the tracker vocabulary and the `ready` guard, which afkkit *invokes* but never re-implements, overrides, or works around (see [Start the issue](#1-start-the-issue)); prkit owns the PR. afkkit only sequences them and owns the escalation policy. Invoking a gate is not owning one: the moment afkkit would have to decide *whether* an issue is workable, it has left its span.
- **No second QA skill.** [Verify](#4-verify) runs the check list the spec gate wrote and records what happened; qakit still owns the QA plan, the human-versus-agent split, and the **Automated verification** section it fills. Verify moves *when* the running happens, not who owns the document, and it invokes no companion kit, so a missing qakit blocks the plan, never the checks.
- **No config file.** Model routing is the table above plus a spoken inline override.

## Notes

- **The `ready` label is the safety property, not who types the command.** Human judgment enters at the grill session that *earns* an issue its `ready` label; typing `issuekit start 42` adds none of its own. So afkkit invoking `start` itself preserves the gate verbatim rather than weakening it: issuekit still refuses everything not `ready`, and afkkit can neither promote an issue to `ready` nor start one that isn't. It cannot get ahead of human judgment because the only door it has is the one locked against exactly that.
- **Escalation is a success, not a failure.** Stopping cleanly at a wall, with no PR, work preserved, and the issue labeled by cause, is afkkit doing its job. The failure mode it exists to prevent is pushing a half-broken or wrongly-assumed change all the way to a PR.
- **Idempotent per issue.** Re-running afkkit on an issue whose worktree already exists picks up from it and continues: issuekit `start` adopts that worktree through gitkit rather than recreating it, and leaves the `in-progress` label alone. That's the intended path for an issue escalated to `needs-planning`, grilled back to `ready`, and re-run, and it runs the same code as a first run.
- **Follow the repo over these defaults.** If a repo has its own review depth, QA location, or PR template, the companion kits already honor those; afkkit doesn't override them.
