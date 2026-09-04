---
name: afkkit
description: >-
  Run a groomed `ready` GitHub issue through the whole build span unattended, covering worktree, implement, commit, verify-and-review, fix, QA plan, and open PR, so one issue reaches a reviewable PR with no human at the keyboard. Use when the user says "run issue #N unattended" or "work the ready issues while I'm away". It starts from a groomed issue; planning and grooming stay attended.
license: MIT
allowed-tools: Bash, Read, Task, Agent, Skill
metadata:
  internal: false
---

# afkkit

The **away-from-keyboard** orchestrator. Hand it a groomed `ready` issue and it drives the middle of the dev workflow from an isolated worktree to an open pull request: implement and commit, verify and review, fix, write a manual QA plan, open the PR, and flip the issue to `in-review`. The human gates stay where judgment lives: planning and grilling happen *before* (the `ready` label is the entry contract), review and merge happen *after*. Deep code review also happens after: a PR-level review bot covers the diff once the PR opens, so afkkit runs exactly one review round in-span.

afkkit adds **no** worktree, tracker, or PR behavior of its own. It **sequences** companion kits (issuekit `start` at the front, then implementkit, commitkit, reviewkit, qakit, and prkit) and owns exactly one thing they don't: the **escalation policy** that decides, at every step, whether to keep going or stop cleanly and leave the issue for a human.

## The contract

- **Input:** an issue number, or `all`. afkkit invokes **issuekit `start <n>`** itself, and issuekit refuses anything not labeled `ready`, gets the worktree from gitkit (off a freshly resolved base ref, adopting an existing one rather than recreating it), and flips `ready → in-progress`. That guard is the safety property, and it holds no matter who types the command: an issue only reaches `ready` after a human grill session, and afkkit can neither promote an issue to `ready` nor start one that isn't.
- **Output on success:** an open PR whose body carries the implementation's documented assumptions, what the acceptance checks confirmed, any unresolved review nits as known follow-ups, and a pointer to a committed QA plan, plus the issue moved to `in-review`.
- **Output on a blocked run:** **no PR.** The worktree and its commits stay intact, a comment on the issue names the precise stuck-state, the issue is labeled for whoever must pick it up, and, in a batch, the next issue starts. afkkit never publishes half-broken work.

## When this fires

- **one issue.** "afkkit 42", "run #42 unattended", "autopilot issue 42", "take #42 to a PR".
- **the whole ready queue.** "afkkit all", "work the ready issues while I'm away", "drain the ready backlog".

If the user names neither an issue number nor `all`, ask which. afkkit never plans, grills, merges, or responds to PR review feedback (see [Non-goals](#non-goals)).

## Preflight (once per invocation)

```sh
gh --version && gh auth status                          # GitHub CLI installed + authenticated
gh repo view --json nameWithOwner -q .nameWithOwner     # inside a repo on GitHub
```

- If `gh` is missing or unauthenticated, stop and point to `https://cli.github.com` / `gh auth login`.
- **Companion-kit check.** afkkit needs implementkit, commitkit, reviewkit, qakit, and prkit. If a kit a step needs is absent, **stop and name it** rather than improvising its job. (Steps below name the plain `gh` fallback where the action is trivial.)
- **issuekit is required, and has no fallback.** It owns the `ready` guard the whole safety property rests on. If it isn't installed, **refuse the run and say to install it**; never re-implement the guard with `gh`. A second copy of a gate is a gate that can drift open, and the copy inside an unattended orchestrator is the one nobody notices drifting.
- **A GitHub tracker is required too, and that is a separate check.** When the repo keeps no GitHub issues, refuse and name that as the reason, and point at **issuekit** `create` to file the plan first. Say it plainly rather than as a missing-dependency error.
- **No shell / CLI available?** Say so and stop; afkkit is an execution orchestrator and there is nothing to reason out in prose.

## How the conductor runs each step

afkkit runs as a **conductor session**: the session you invoke it in sequences the pipeline, and each heavy step runs as a **subagent** dispatched to work inside the issue's worktree. The bulk of the tokens live in the subagents, and each step runs on the model that fits it.

- **Dispatch a subagent per step** with the host's subagent tool: `spawn_agent` on Codex, or `Task` or `Agent` on Claude-compatible hosts (agent type `general-purpose`). Pass it the **worktree path**, the **run-directory files this step reads** (see [The run directory](#the-run-directory)), the **companion skill to invoke**, and the **model** from [Model routing](#model-routing). The subagent's first action is to work inside that worktree path; its second is to read the run-directory files it was handed.
- **The worktree path is carried run state, not the conductor's location.** The conductor's own working directory never changes; it holds each issue's path and dispatches into it. That is what lets one conductor walk a batch without being inside any worktree.
- **A dispatch has a floor.** Every subagent pays a fixed cost before it does any work (spawn, orient, report back). So **a step that needs nothing but the previous agent's context does not get its own dispatch.** This is the rule that folds the commit, the QA plan, and the PR into the agents already holding the work, and it is the test any new step must pass before it earns a dispatch of its own. The floor's converse also holds: a step that needs only the *repository state* a previous agent produced, and none of its reasoning, gets a fresh dispatch, which is why [Implement](#3-implement) runs one dispatch per phase group.
- **Each subagent returns a small structured result**: pass/fail, plus the identifiers and one-line summaries the conductor needs to decide the next move. **The payload itself goes in a file, not in the return.**
- **The conductor redistributes payloads by reference; it never re-derives or re-types them.** Every payload class has a file, so a hand-off is a path plus the identifiers that matter (`apply B1, B3, N2 from .afkkit/findings.md`), never a paragraph of re-quoted evidence.
- **What the conductor may do, and may not.** It **dispatches**, **redistributes**, **reads** the workspace to verify a claim ([the escalation contract](#the-escalation-contract) names the case that requires it), and **decides** the next move. It **never writes to the workspace**: no editing code, no building, no staging, no committing. Between dispatches it says what it is doing in one line and batches its bookkeeping reads into single shell calls, because its whole accumulated context re-bills on every turn it takes.
- **No subagent capability?** Run the steps inline in sequence in the conductor session. You lose per-step model routing but the pipeline and escalation policy are unchanged. Say you're running inline.
- **Task-tracking tools are not run state.** A harness task list is a fine progress display but it is not durable. The pipeline below is the tracker; the issue's labels and comments are the record.

## The run directory

Each step writes its payload down once, in one place, and every later step reads the path. Without that, every later step re-derives the same repo facts from cold, and a rediscovery costs far more than the fact is worth because every tool use re-bills the agent's whole accumulated context.

- **Where.** `.afkkit/` at the **worktree root**, excluded from git so nothing in it reaches the PR diff. Register it in the repo's private exclude file:

  ```sh
  git -C <worktree> rev-parse --git-path info/exclude    # resolve the real path first
  ```

  **Ask git for that path; never hardcode `.git/info/exclude`.** In a linked worktree `.git` is a *file*, not a directory. Append `.afkkit/` only if it isn't already listed; the exclude file is shared across worktrees.

- **What's in it.**

  | File | Written by | Read by |
  |------|-----------|---------|
  | `orientation.md` | [spec gate](#2-spec-gate) | every later step |
  | `assumptions.md` | [spec gate](#2-spec-gate) | [Fix and finish](#5-fix-and-finish) (PR body) |
  | `checks.md` | [spec gate](#2-spec-gate) | [Verify and review](#4-verify-and-review), [Fix and finish](#5-fix-and-finish) |
  | `verified.md` | [Verify and review](#4-verify-and-review), refreshed by [Fix and finish](#5-fix-and-finish) | [Fix and finish](#5-fix-and-finish) (QA plan) |
  | `findings.md` | [Verify and review](#4-verify-and-review) | [Fix and finish](#5-fix-and-finish) |

- **What goes in `orientation.md`.** Facts, each with its source: the gate command and its result, paths that exist, the symbol or config that governs the behavior being changed, the issue's acceptance criteria restated concretely. **Never conclusions**: "the auth flow is fine" is not a fact, where "`src/auth/session.ts:40` sets the cookie `maxAge` from `SESSION_TTL`" is. If it grows past roughly a page, the gate is writing an essay instead of an index.
- **Findings carry stable identifiers.** The review writes `B1`, `B2` for blockers and `N1`, `N2` for nits, so a fix round is dispatched by reference instead of a paragraph of re-quoted evidence.
- **Trade-off, stated plainly.** Every downstream step inherits the gate's understanding instead of re-deriving it, so a *wrong* orientation propagates silently. That is the price of not paying for the same discovery five times, and it is why both files carry facts-with-sources rather than judgments: a wrong path is caught the moment a step opens it, a wrong conclusion is not.
- **No writable filesystem?** The conductor holds each payload and pastes it into the dispatch prompts that need it, and says that's what it's doing.

## Model routing

The routing surface is two rules plus a spoken override; there is no config file.

- **Every step runs on the host's primary writer model**: `opus` on Claude-compatible hosts, `gpt-5.6-sol` (reasoning `high`, `xhigh` for the start + spec gate dispatch) on Codex.
- **[Verify and review](#4-verify-and-review) runs on a different model family**: `fable` on Claude-compatible hosts, `gpt-5.5` (reasoning `high`) on Codex. An implementer and reviewer from the same family share blind spots by construction; the independence is bought exactly once, on the one review round the run has.

Write the host's **alias**, never a dated model snapshot. Never send one host's model name to the other; if the host is ambiguous or a model is unavailable, omit the override and let the subagent inherit the conductor's model. The user can override any step's model at invocation in plain language ("afkkit 42, review on gpt-5.5"); validate the requested model against the active host before dispatch.

**How a step's cost actually works.** Every tool use re-bills the agent's entire accumulated context, so cost tracks **context size × turns**, not token volume. The way to make a step cheap is to hand it what it needs, not to ask it to think less, and the cheapest step is the one that never gets its own dispatch. **Never budget Implement, the spec gate, or the verify probe**: the work costs what it costs, and nudging those three toward fewer tool uses buys cheaper, worse output. Do state the budget for the mechanical tails ("this is a mechanical step: read the run-directory files and the diff, produce the output, don't go exploring the codebase") inside [Fix and finish](#5-fix-and-finish)'s QA and PR portions.

## The pipeline (per issue)

Run these in order for each issue. Any step that can't proceed hands to [the escalation contract](#the-escalation-contract) and the issue stops there, cleanly, with no PR.

### 1. Start the issue

Start shares one dispatch with the [spec gate](#2-spec-gate): dispatch a subagent that invokes **issuekit** `start <n>` and, when start succeeds, continues straight into the gate inside the worktree it just acquired. afkkit adds nothing to `start` and re-implements none of it: issuekit refuses any issue not labeled `ready`, asks **gitkit** for the worktree (branch `issue-<n>-<slug>`, adopting an existing one rather than recreating it), and flips the label `ready → in-progress`.

**Say the run is unattended when you invoke it.** issuekit previews every mutation and waits for an OK, except its label writes, which run unprompted for every caller. Saying the run is unattended tells every later step there's nobody to answer a prompt.

On a refusal the subagent returns a structured refusal naming **which** case it hit, verbatim, and never begins the gate. On success it returns `{worktree, branch, label}` together with the gate's outputs. Then the conductor verifies what came back, as **one** shell call:

```sh
git -C <worktree> rev-parse --show-toplevel \
  && git -C <worktree> branch --show-current \
  && gh issue view <n> --json labels -q '.labels[].name'   # real worktree, right branch, label now in-progress
```

Hold that path as this issue's run state; every subagent below is dispatched into it.

**If issuekit refuses, that's a preflight stop, not [an escalation](#the-escalation-contract)**, because nothing has happened yet. Report the reason issuekit gave and, in a batch, move to the next issue:

- **`needs-planning`** → the decisions aren't settled; it needs a human grill session first.
- **`blocked`** → name the `Blocked by #N` prerequisite and its state.
- **closed, or carrying no lifecycle label** → say which; issuekit `triage` is what classifies it.

An issue already `in-progress` is **not** a refusal. issuekit takes its adopt path, gitkit hands back the existing worktree, and afkkit continues. That covers both a re-run after grilling and a worktree a human staged by hand, on the same code path as a first run.

### 2. Spec gate

The gate runs in [the start dispatch](#1-start-the-issue): the same agent reads the issue body and the relevant code, and classifies any gaps between what the issue specifies and what building it requires. It is the only step that explores the repo before any code exists, so it also writes down everything the run needs later: `orientation.md`, `assumptions.md`, and `checks.md` in [the run directory](#the-run-directory), plus the classification below and the issue's phase grouping.

**The phase list is a return value, and the gate groups it.** An issue written by issuekit carries `## Phase N` headings. The gate returns them in order, **grouped into dispatch groups**: a heavy phase stands alone, consecutive light phases fold into one group. The test is whether a phase needs a fresh context of its own. [Implement](#3-implement) dispatches one subagent per group. A body with no phase headings returns a single unnamed group.

The classification:

- **Missing decisions.** Product choices or trade-offs a human would have to make. → **Escalate as a planning gap:** stop before writing any code, comment the exact open questions on the issue (phrased as grill-questions), and flip `in-progress → needs-planning`. Move to the next issue.
- **Missing mechanics only.** File names, minor edge cases, naming, ambiguities a competent implementer fills uncontroversially. → **Proceed.** The gate writes every mechanical choice to `assumptions.md`, and the PR body carries the path so the reviewer sees exactly what was assumed.

A `ready` issue *should* clear this gate, because grilling is what earns `ready`. The gate is the backstop for a decision that slipped through: never build on an un-made decision.

**The gate also writes the check list.** `checks.md` holds one entry per acceptance criterion: an identifier, the **observable** that would confirm it, a **provisional command**, and a flag for whether an agent can confirm it or only a human can. Because the gate runs before any code exists, the checks test what the issue asked for, not what the code happens to do. Write the observable precisely and the command approximately; [Verify and review](#4-verify-and-review) adapts the command to what actually shipped.

### 3. Implement

Dispatch a subagent (worktree) to invoke **implementkit** against the issue spec. implementkit resolves its own straight-through-vs-TDD mode and enforces the repo's own test + build gate before it reports done. Two failure shapes route differently:

- implementkit **bounces the spec as too thin** → a *decision* gap the gate missed. Escalate to `needs-planning` with the specific gap commented.
- implementkit **can't get the gate green** → an *execution* failure. Escalate keeping `in-progress`, with the failing gate output commented.

**Then the same subagent commits, before it returns**, through **commitkit** (fallback: a single `git add -A && git commit` with a conventional subject from the issue title). Say so in the dispatch prompt, because implementkit's own contract stops short of committing.

**A multi-phase issue gets one implement dispatch per phase group**, in order, each invoking implementkit narrowed to its group's phases and each committing before it returns. Phase N+1 needs phase N's *committed code*, not its transcript, so a fresh agent starts from a clean tree and the branch carries the hand-off. A group that escalates stops the run there, and the escalation comment names the phases already committed and the phase that stopped, so a re-run resumes rather than rebuilding. **Every step after this one runs once**, over the whole branch diff: reviewing per phase would split the reviewer's judgment across pieces it cannot see whole.

**The conductor does not tick the issue's phase checkboxes.** The exemptions in this pipeline cover label writes only, and a checkbox edit is not a label write. The commits on the branch are the record while the run is live.

### 4. Verify and review

One dispatch, on the [independent review model](#model-routing), does the run's whole quality pass: it **runs the code first, then reviews the diff**, so the review ranks live evidence instead of reading alone. Hand it the worktree, `checks.md`, `orientation.md`, the fact that implementkit's gate is already green, and where the build output lands. Its job, in order:

1. **Run every agent-confirmable check in `checks.md`.** Adapt each provisional command to what actually shipped, and record the command it really ran.
2. **Probe past the list, at most six times.** Error paths, degraded or missing inputs, the stdout/stderr split, an absent prerequisite. Live probing is the one lens diff-reading does not have, and it is where surprise defects come from.
3. **Write `verified.md`**: ✅ or ❌ per check, the real output, the exact commands, and an explicit list of **what it did not check**. A capped step that reports full coverage is worse than one that never ran.
4. **Invoke reviewkit against the full branch diff**, with `verified.md` in hand, and **write the findings to `.afkkit/findings.md`**, never to `docs/reviews/`: the run directory is excluded from git, which is where working notes belong. Findings carry stable IDs (`B1`… blockers, `N1`… nits). A ❌ from the checks is ranked here through reviewkit's own requirement-completeness pass; afkkit adds no second severity classifier.

Hard rules for the verification half: **never edit code or copy files into the workspace**, because a failure is evidence for the review, not something to work around; **never rebuild, rescaffold, or install**, except when the change's subject *is* the build path; **never re-derive** a fact `orientation.md` already holds; and when a check needs a dev server, **start it once, run every check that needs it, stop it, and record the exact start and stop commands in `verified.md`**.

**Tell the subagent it is the fresh reviewer.** reviewkit's own rule is to hand its passes to a fresh subagent, but this dispatch has already satisfied that: the agent has no memory of the implementation. Say so, and say it must run the passes itself, or it delegates again and a second agent re-reads the entire branch diff.

It returns the verdict, pass/fail counts, the blocker IDs with one line each, and the nit IDs. **One exception escalates immediately:** if the change **does not run at all**, that is an execution gap; escalate keeping `in-progress` and don't pay for a review of code that can't start.

**This is the run's only review round.** A PR-level review bot covers the diff again after the PR opens, so surviving depth belongs there, not in a second in-span round.

### 5. Fix and finish

One tail dispatch, on the writer model, carries the issue from findings to open PR. Dispatch it with paths, never prose: `findings.md` and the IDs to apply, `checks.md`, `verified.md`, `orientation.md`, and `assumptions.md`. Its job, in order:

1. **Apply every blocker plus every cheap, concrete nit** from `findings.md`, by ID, through **implementkit**'s fix round. Nits too big for the sweep go to the PR body as known follow-ups. If it cannot fix a blocker, or cannot get the repo's gate green, it stops and reports which ID stuck; the conductor escalates keeping `in-progress`, and **no PR opens with known blockers in it**. When the review returned zero findings, this step starts at the next item.
2. **Re-run the checks its changes touch and refresh those entries in `verified.md`**, then **commit through commitkit**. It is already warm in the files, so this costs a handful of turns.
3. **Write the QA plan** by invoking **qakit**, which writes to `docs/qa/qa-<slug>-YYYY-MM-DD.md` and fills its **Automated verification** section from `verified.md`. The checking is done by now: **this transcribes recorded outcomes and writes the manual cases; it re-runs nothing, rebuilds nothing, and starts no server.** The human-only entries the gate flagged in `checks.md` are the manual cases, arriving pre-made. Leave the doc uncommitted; prkit commits it next.
4. **Open the PR** by invoking **prkit**, handing it paths: `assumptions.md`, `findings.md` plus the unresolved nit IDs, `verified.md`, any **unmet acceptance criteria** surfaced by [the escalation contract](#the-escalation-contract), and the QA-plan path, which prkit commits before it pushes. prkit writes the title and body from the real commits and diff, pushes, opens the PR, and advances the issue to `in-review`. **That advance runs unprompted** under prkit's own label exemption. Only if prkit is absent does the conductor fall back to `gh issue edit <n> --remove-label in-progress --add-label in-review` after the agent opens the PR by hand.

For the QA and PR portions, state the deliberation budget in the prompt: they are mechanical, the inputs are the run-directory files and the diff, and exploring the codebase is the waste.

This is the successful terminus: an open PR, a committed QA plan, and an `in-review` issue.

### 6. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Nobody watched this run, so the report is the handover.

**What changed.** Give one outcome line for the issue: **opened** (PR link), **escalated** (which label, one-line reason, issue link), or **skipped** (issuekit refused it, with the reason, and the fact that nothing was mutated). In a batch, accumulate these for the batch summary.

**Where it landed.** Give the worktree path and branch. On an escalation this is load-bearing: the commits are real work on disk. A skipped issue has no worktree; say that plainly.

**Next.** Route by outcome, naming a sibling kit only when it's installed and otherwise describing the action plainly:

- **opened** → the PR needs a human reviewer. **mergekit `start <n>`** pulls it down into the worktree it was built in; the committed QA plan is what they run by hand.
- **escalated to `needs-planning`** → run a grill session with **grillkit** on the issue's open questions, then re-run afkkit once it's back to `ready`.
- **escalated, still `in-progress`** → execution is stuck. Point at the commented gate output or surviving blockers; pick it up in the existing worktree by hand.

Crown **one** next move even after a batch, usually the oldest open PR. Route, don't launch: afkkit never invokes mergekit or grillkit itself.

**Metrics print only on request.** When the invocation asks for them ("afkkit 42 with metrics"), print one table per issue: one row per dispatched step (a per-group implement dispatch names its phases), with model, time, tool uses, tokens, and cache read/write columns **only where the harness actually reports them**. Never estimate a number; the table exists to correct [Model routing](#model-routing) from real data. The conductor fills it from what each dispatch reports back and measures nothing itself. The metrics live in the report and nowhere else; afkkit writes no run-report artifact.

## The escalation contract

The one policy afkkit owns. Whenever a step can't proceed, **escalate** rather than push forward.

**First, verify a "pre-existing" claim before accepting it.** A step that reports a gate as red-but-already-broken is asking to be excused from the one check between an unattended run and a shipped regression, and a failure it caused and a failure it inherited look identical from inside the worktree. The conductor re-runs that command against the **base branch** (a *read*, inside its boundary) and only then accepts the claim:

- **The base is green too.** The failure belongs to this branch. Treat it as an execution gap and escalate on it.
- **The base is red as well.** The claim holds, and the run continues. But if the failure means an **acceptance criterion cannot be met from repo state**, that goes into the PR body as an explicit unmet criterion. Read `verified.md` before deciding a criterion is unmet; don't infer it from a failing gate.

**A step that needs consent, with nobody to ask, escalates.** A dispatched step that reaches a preview-and-confirm gate stops rather than assuming a yes: keep `in-progress`, comment what the step was about to do, and move on. The exception is a mutation the owning skill exempts for **every** caller: issuekit `start`'s `ready → in-progress` flip and prkit's `in-review` advance both run unprompted. afkkit relies on the exemptions the owning skill already wrote and never widens one.

Then escalation always means the same five things:

1. **No PR.**
2. **Keep the work.** Leave the worktree and every commit intact.
3. **Comment the stuck-state** on the issue, precisely: the open questions for a planning gap, the failing gate output for an execution gap, the surviving blocker IDs for a review gap. On a multi-phase issue, name the phases that committed and the phase that stopped.
4. **Set the label by *cause*.** A **planning gap** (a missing *decision*, from the [spec gate](#2-spec-gate) or implementkit) → flip `in-progress → needs-planning`; it goes back to the human's grill queue. An **execution gap** (tests won't go green, or blockers survive the fix round) → **keep `in-progress`**; the spec was fine.
5. **Continue the batch.**

## Batch mode: `all`

`afkkit all` takes its queue from `gh issue list --label ready --json number,title,labels,updatedAt` and walks it **sequentially**, running the full pipeline on each. Sequential is deliberate: Implement dominates the wall clock and is irreducibly serial, parallel branches off one base make merge conflicts unpredictable, and parallel conductor sessions share one usage budget and stall each other into session limits. Queue the issues into one conductor.

- **Order the queue by priority.** issuekit's priority labels come back in the same `labels` array: highest first, then oldest-updated within a level, unassessed last. Fall back to oldest-first when no issue carries a priority, and say so in the preview. An explicit order the user names beats both. **Priority orders the queue and relaxes nothing**: a `critical` issue still needs `ready`, still faces the spec gate, and still escalates rather than guessing.
- **One confirmation, up front.** Print the queue (number, priority, title, in walk order) and wait for a single OK before starting anything. After that OK the run is unattended: no further prompts, whatever happens. A single-issue invocation needs no confirmation, because naming the number *is* the intent.
- **The queue is fixed at that OK**, never re-read before each issue. The run mutates labels as it goes, so re-reading would drain issues nobody approved.
- **Issues start just in time**, each at the top of its own pipeline run: the worktree branches off a freshly fetched base, and a batch that stops early leaves unreached issues untouched in `ready`.
- **`all` drains `ready` only.** An issue already `in-progress` may have a human in its worktree, so the batch passes over it; name it explicitly (`afkkit 42`) to include it. **`stacked` issues are passed over too**: a batch cannot safely chain them, because one bad bottom layer poisons every layer above it. **List both kinds in the up-front preview with their priorities and say why they were skipped**; silence reads as "unworkable" when the truth is that only this runner declines them.
- **Drop each issue's payloads once it terminates.** Keep the one-line outcome for the batch summary and let the paths go; a batch working its tenth issue must not still pay for the first one's findings on every turn.

At the end, print the **batch summary**: PRs opened (with links), escalations by state (with links and one-line reasons), skips and why, and, when the run didn't finish the queue, **which issues it never reached, with their priorities**. Then give the single crowned next move from [Hand off](#6-hand-off). That summary plus GitHub's own notifications is the whole signal surface.

## Non-goals

- **No planning or grilling.** A thin spec goes back to the human queue as `needs-planning`. plankit and grillkit stay interactive.
- **No second review round in-span.** The run reviews once, on the independent model; deeper review belongs to the PR-level review bot and the human reviewer after the PR opens.
- **No PR-feedback loop, no merge, no teardown.** The span ends at PR open. issuekit `close` runs after merge, out of span.
- **No parallel batches, no browser verification, no push notifications.** GitHub plus the session summary are the only signal.
- **No stack chain-draining.** `all` skips `stacked` issues and says it did; a named `stacked` issue runs like any other because issuekit's guard verifies the prerequisite's PR itself.
- **No new worktree, tracker, or PR logic.** gitkit owns the worktree lifecycle, issuekit owns the tracker vocabulary and the `ready` guard, prkit owns the PR. afkkit sequences them and owns the escalation policy. Invoking a gate is not owning one: the moment afkkit would have to decide *whether* an issue is workable, it has left its span.
- **No config file.** Model routing is [the two rules above](#model-routing) plus a spoken inline override.

## Notes

- **Escalation is a success, not a failure.** Stopping cleanly at a wall, with no PR, work preserved, and the issue labeled by cause, is afkkit doing its job.
- **Idempotent per issue.** Re-running afkkit on an issue whose worktree exists adopts it through issuekit `start` and continues, on the same code path as a first run.
- **Follow the repo over these defaults.** If a repo has its own review depth, QA location, or PR template, the companion kits already honor those; afkkit doesn't override them.
