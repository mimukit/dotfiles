---
name: afkkit
description: >-
  Run a groomed `ready` GitHub issue through the whole build span unattended — worktree, implement, commit, review, fix, QA plan, and open PR — so one issue reaches a reviewable PR with no human at the keyboard. Use when the user says "afkkit", "run issue #N unattended", "work the ready issues while I'm away", "autopilot this issue", "take this issue to a PR without me", or wants the middle of the kit workflow driven end to end on its own.
license: MIT
allowed-tools: Bash, Read, Task, Skill
metadata:
  internal: false
---

# afkkit

The **away-from-keyboard** orchestrator. Hand it a groomed `ready` issue and it drives the middle of the dev workflow — the part that needs no human judgment once the issue is well-specified — from an isolated worktree to an open pull request: implement, commit, review, fix, write a manual QA plan, open the PR, and flip the issue to `in-review`. The human gates stay where judgment lives: planning and grilling happen *before* (the `ready` label is the entry contract), review and merge happen *after*.

afkkit adds **no** worktree, tracker, or PR behavior of its own. It **sequences** companion kits — implementkit, commitkit, reviewkit, qakit, prkit — plus a manual, human-run orcakit step at the very front, and owns exactly one thing they don't: the **escalation policy** that decides, at every step, whether to keep going or stop cleanly and leave the issue for a human. It is the autonomous sibling of statuskit: statuskit tells a human what to do next; afkkit does the next several things itself and stops at the boundary where a human is genuinely required.

## The contract

- **Input:** an issue whose worktree the human has already created manually. A human runs `orcakit start <n>` themselves — which refuses anything not labeled `ready`, flips `ready → in-progress`, and creates the worktree off fresh `origin/main` — then switches into that worktree and launches (or resumes) the afkkit conductor session from inside it. That manual step is the whole safety property: an issue only reaches orcakit's guard after a human grill session (see the lifecycle below), so afkkit never works anything that hasn't already had human judgment applied. afkkit itself never invokes orcakit — it only verifies the precondition (see [Confirm the worktree](#1-confirm-the-worktree)).
- **Output on success:** an open PR whose body carries the implementation's documented assumptions, any unresolved review nits, and a pointer to a committed QA plan — and the issue moved to `in-review`.
- **Output on a blocked run:** **no PR.** The worktree and its commits stay intact, a comment on the issue names the precise stuck-state, the issue is labeled for whoever must pick it up, and — in a batch — the next issue starts. afkkit never publishes half-broken work.

Everything between input and output is mechanical sequencing plus the escalation policy.

## When this fires

The user wants an issue taken through the build span without sitting through it:

- **one issue** — "afkkit 42", "run #42 unattended", "autopilot issue 42", "take #42 to a PR".
- **the whole ready queue** — "afkkit all", "work the ready issues while I'm away", "drain the ready backlog".

If they name neither an issue number nor `all`, ask which. afkkit never plans, grills, merges, or responds to PR review feedback — those are human or out-of-scope (see [Non-goals](#non-goals)).

## Preflight (once per invocation)

Before touching anything, confirm the tooling and the conductor:

```sh
gh --version && gh auth status                          # GitHub CLI installed + authenticated
gh repo view --json nameWithOwner -q .nameWithOwner     # inside a repo on GitHub
```

- If `gh` is missing or unauthenticated, stop and point to `https://cli.github.com` / `gh auth login` — don't work around it.
- **Companion-kit check.** afkkit is glue: it needs implementkit, commitkit, reviewkit, qakit, and prkit to do the actual work. Check which are installed. If a kit a step needs is absent, **stop and name it** rather than improvising its job badly — an orchestrator missing its steps degrades by refusing clearly, not by half-doing the work. (Each step below also names the plain `gh` fallback where the action is trivial enough to run directly.) orcakit is a prerequisite the human runs manually before invoking afkkit (see [Confirm the worktree](#1-confirm-the-worktree)) — afkkit never dispatches it itself, so it's outside this check.
- **Conductor model.** The review step inherits the model of the session you launch afkkit in (see [Model routing](#model-routing)). If that session is on a mid-tier model, warn once: review quality is only as good as the conductor's model, so afkkit is best launched on a top-tier model (fable/opus).
- **No shell / CLI available** (e.g. a browser-based agent)? You can't run `gh`, `orca`, or spawn subagents. Say so and stop — afkkit is an execution orchestrator; there's nothing to reason out in prose. Point the user at running the individual kits interactively instead.

## How the conductor runs each step

afkkit runs as a **conductor session**: the session you invoke it in sequences the pipeline, and each heavy step runs as a **subagent** dispatched to work inside the issue's worktree. This keeps the conductor's context small (the bulk of the tokens live in the subagents) and lets each step run on the model that fits it.

- **Dispatch a subagent per step** with the Task tool (agent type `general-purpose`), passing it three things: the **worktree path** (created manually by the human via `orcakit start <n>` before this run began), the **companion skill to invoke** for that step, and the **model** from the table below. The subagent's first action is to work inside that worktree path (operate on its absolute paths, or `cd` into it) — the conductor's own working directory is that same worktree, not the main checkout (see [Confirm the worktree](#1-confirm-the-worktree)).
- **Each subagent returns a small structured result** the conductor acts on: pass/fail, and the step's payload (the gate's assumptions list, the review's blocker/nit findings, the QA doc path). The conductor holds the thread; the subagents hold the work.
- **The conductor never edits code or runs the build itself** — it dispatches, reads the result, and decides the next move (continue, loop, or escalate). That decision — the escalation policy — is the one thing afkkit owns.
- **No subagent capability?** Degrade to running the steps inline in sequence in the conductor session. You lose per-step model routing (everything runs on the conductor's model) but the pipeline and escalation policy are unchanged. Say you're running inline.

## Model routing

Default per-step models, chosen so cheap mechanical work runs cheap and judgment work runs strong:

| Step | Model | Why |
|------|-------|-----|
| Spec gate | sonnet | A fast classification, not deep reasoning. |
| Implement | sonnet | The bulk of the work; a mid model implements a settled spec well. |
| Commit | sonnet | Mechanical — group the diff, write the message. |
| Review | **conductor's model** | The quality gate; inherits the strong model you launched the session on (fable/opus). |
| Fix | sonnet | Applying review findings against a concrete list. |
| QA plan | sonnet | Grounded generation from the diff. |
| PR | sonnet | Title/body from the commits and diff. |

**Inline override.** The user can override any step's model at invocation in plain language — "afkkit 42, implement on opus", "afkkit all, review on fable". Honor the override for the named step(s); everything else keeps the table. There is no config file — the table plus the spoken override is the whole routing surface.

## The pipeline (per issue)

Run these in order for each issue. Any step that can't proceed hands to [the escalation contract](#the-escalation-contract) and the issue stops there — cleanly, with no PR.

### 1. Confirm the worktree

afkkit does not create or switch worktrees — that's a manual step the human does *before* invoking afkkit, by running **orcakit** `start <n>` themselves. orcakit's `ready`-label guard is the entry gate: it refuses any issue not labeled `ready`, creates the worktree off fresh `origin/main`, links it to the issue, and flips the label `ready → in-progress`. The human then switches into that worktree and launches (or resumes) the afkkit conductor session from inside it.

afkkit's own job here is to verify that precondition actually holds, not to take it on faith:

```sh
git branch --show-current                              # must not be main/master
git rev-parse --show-toplevel                           # must be the worktree path, not the main checkout
gh issue view <n> --json labels -q '.labels[].name'      # must include in-progress, not ready
```

- If the current branch is `main`/`master`, or the working directory is the primary checkout rather than a distinct worktree, **don't just error — stop and ask the human to confirm**: state plainly that this looks like the main branch/checkout rather than an issue worktree, and ask them to verify they've run `orcakit start <n>` and switched into the resulting worktree before afkkit continues. Don't guess or proceed on an assumption either way.
- If the issue is still labeled `ready` (orcakit hasn't run yet), stop and tell the human to run `orcakit start <n>` manually, switch into the resulting worktree, and re-invoke afkkit from there. This is a hard preflight stop, not a pipeline escalation — nothing has happened yet, so there's no comment or label churn.

If a worktree for this issue already exists (the re-run path — an issue that was escalated to `needs-planning`, grilled by a human back to `ready`, and re-run), the human re-runs `orcakit start <n>` themselves to adopt it rather than recreating, then switches in as before.

### 2. Spec gate

Dispatch a subagent (sonnet) to read the issue body and the relevant code in the worktree, and classify any gaps between what the issue specifies and what building it requires. The classification is the whole point:

- **Missing decisions** — product choices or trade-offs a human would have to make (which behavior is correct, which of two designs, an unstated requirement). These are exactly what a grill session settles. → **Escalate as a planning gap:** stop before writing any code, this is the cheapest possible failure point. Comment the exact open questions on the issue (phrased as the grill-questions a human should answer), and flip the label `in-progress → needs-planning` so the issue lands in the human's planning queue. Move to the next issue.
- **Missing mechanics only** — file names, minor edge cases, naming, small ambiguities a competent implementer fills uncontroversially. → **Proceed.** The subagent returns an **assumptions list** — every mechanical choice it's making — which the conductor carries forward to the PR body so the reviewer sees exactly what was assumed.

A `ready` issue *should* clear this gate — grilling is what earns `ready`. The gate is the backstop for a decision that slipped through, and routing it to `needs-planning` rather than guessing is the design's core stance: never build on an un-made decision.

### 3. Implement

Dispatch a subagent (sonnet, working in the worktree) to invoke **implementkit** against the issue spec. implementkit resolves its own straight-through-vs-TDD mode and enforces the repo's own test + build gate before it reports done — afkkit doesn't second-guess that. Two failure shapes route differently:

- implementkit **bounces the spec as too thin** — it hit a genuine *decision* gap the [spec gate](#2-spec-gate) missed. Treat it as a planning gap: escalate to `needs-planning` with the specific gap commented.
- implementkit **can't get the gate green** after its own bounded fixes — an *execution* failure, not a spec problem. Escalate keeping `in-progress`, with the failing gate output commented.

Otherwise, implementkit leaves green, unstaged changes in the worktree and afkkit continues.

### 4. Commit

Dispatch a subagent (sonnet, worktree) to invoke **commitkit**, which groups the unstaged changes and writes Conventional-Commits messages from the diff. This banks the initial implementation before review. If commitkit isn't installed, the fallback is a single `git add -A && git commit` with a conventional subject derived from the issue title.

### 5. Review

Dispatch a subagent (**conductor's model**, worktree) to invoke **reviewkit** against the branch diff. reviewkit returns severity-ranked findings across its passes. The conductor splits them into **blockers** (correctness, completeness, security — must fix) and **nits** (polish, style — fix once, don't gate on). This split drives the fix loop.

### 6. Fix loop

Bounded at **two fix rounds**. Per round:

1. Dispatch a subagent (sonnet, worktree) to invoke **implementkit** in fix mode against the concrete blocker list from [Review](#5-review).
2. Commit the fixes (**commitkit**, sonnet).
3. Re-review (**reviewkit**, conductor's model) — but only re-run a full review while **blockers** remain; nits are fixed once in the first round and never trigger another round.

Stop the loop when no blockers survive. If blockers still survive after the second round, or a fix round can't get the gate green, **escalate keeping `in-progress`** — comment the surviving blockers (or the red gate) and move on. No PR opens with known blockers in it. Nits that were never worth a round are carried to the PR body as "known follow-ups".

### 7. QA plan

Dispatch a subagent (sonnet, worktree) to invoke **qakit**, which writes a manual QA plan grounded in the diff to `docs/qa/qa-<slug>-YYYY-MM-DD.md` and runs any agent-verifiable checks itself. Then commit that doc (**commitkit**) so it travels with the branch. The PR body will point at it.

### 8. Open the PR

Dispatch a subagent (sonnet, worktree) to invoke **prkit**, handing it three things to fold into the PR body: the **assumptions list** from the [spec gate](#2-spec-gate), the **unresolved nits** carried from the fix loop, and the **QA-plan path**. prkit writes the title and body from the real commits and diff, pushes the branch, opens the PR, and — its existing behavior — advances the linked issue `in-progress → in-review`. afkkit relies on prkit for that label flip rather than duplicating it; only if prkit is absent does the conductor fall back to `gh issue edit <n> --remove-label in-progress --add-label in-review` after opening the PR by hand.

This is the successful terminus: an open PR, a QA plan, and an `in-review` issue.

### 9. Report

Emit one outcome line for the issue: **opened** (PR link) or **escalated** (which label, one-line reason, issue link). In a batch, accumulate these; the batch summary is emitted at the end (see [Batch mode](#batch-mode-all)).

## The escalation contract

The one policy afkkit owns. Whenever a step can't proceed, **escalate** rather than push forward — and escalation always means the same five things:

1. **No PR.** Never open a pull request from a run that hit a wall.
2. **Keep the work.** Leave the worktree and every commit intact — the next human (or the re-run) picks up from real progress, not a clean slate.
3. **Comment the stuck-state** on the issue, precisely: the open questions for a planning gap, the failing gate output for an execution gap, the surviving blockers for a review gap.
4. **Set the label by *cause*** — this is the load-bearing distinction:
   - **Planning gap** (the [spec gate](#2-spec-gate) or implementkit found a missing *decision*) → flip `in-progress → needs-planning`. The spec itself is incomplete, so it goes back to the human's grill queue. A re-run after grilling adopts the existing worktree.
   - **Execution gap** (tests won't go green, or review blockers survive the fix loop) → **keep `in-progress`**. The spec was fine; execution is stuck. The comment and batch summary carry the detail for a human to unstick — no label churn, because the issue isn't waiting on a *decision*.
5. **Continue the batch.** One escalated issue never sinks the run — the next `ready` issue starts.

## Batch mode: `all`

Because [Confirm the worktree](#1-confirm-the-worktree) is a manual human step, `afkkit all` requires the worktrees to already exist: run `orcakit start <n>` yourself for every `ready` issue you want in this batch *before* invoking `afkkit all` — each run flips that issue's label `ready → in-progress` and creates its worktree off fresh `origin/main`. afkkit then discovers the pre-staged worktrees (e.g. via `orca worktree list` or `git worktree list`, matched to their linked issue) and walks them **sequentially**, running [Confirm the worktree](#1-confirm-the-worktree) and the rest of the pipeline on each without ever invoking orcakit itself.

Sequential, not parallel: v1 keeps merge-conflict and resource behavior predictable, and a returning human faces one PR at a time rather than a pile of concurrent branches off `origin/main`. Process oldest-first (or by the order the user names). Each issue is independent — an escalation is logged and the walk continues to the next.

At the end, print the **batch summary**: how many PRs opened (with links), how many escalated and to which state (`needs-planning` vs still `in-progress`, with links and one-line reasons). That summary plus GitHub's own PR notifications is the whole signal surface — afkkit writes no run-report artifact and sends no push notifications. Success is the PR itself; a blocked issue is a comment and a label the human sees on return.

## Non-goals

afkkit is deliberately narrow — the middle of the workflow, nothing else:

- **No planning or grilling.** It never invents product decisions; a thin spec goes back to the human queue as `needs-planning`. plankit and grillkit stay interactive and out of the unattended path.
- **No PR-feedback loop, no merge, no teardown.** The span ends at PR open. Responding to a human's review comments is a designed-for *later phase*, not v1. Merging is a human gate. orcakit `finish` (close the issue, remove the worktree) runs *after* merge — also out of span.
- **No parallel batches, no browser verification, no notifications** in v1 — issues run sequentially, verification is qakit's manual plan (not verifykit's browser capture), and GitHub plus the session summary are the only signal.
- **No new worktree, tracker, or PR logic, and no worktree creation of its own.** orcakit owns the worktree lifecycle and is run manually by the human before afkkit starts (see [Confirm the worktree](#1-confirm-the-worktree)); issuekit owns the tracker vocabulary, prkit the PR. afkkit only sequences the rest and owns the escalation policy.
- **No config file.** Model routing is the table above plus a spoken inline override.

## Notes

- **The `ready` label is the safety property.** afkkit works only what a human already grilled into `ready` — enforced by orcakit's guard when the human manually runs `orcakit start <n>`, not by afkkit itself. afkkit only verifies that guard already fired (see [Confirm the worktree](#1-confirm-the-worktree)); it cannot get ahead of human judgment because it refuses to start on anything else.
- **Escalation is a success, not a failure.** Stopping cleanly at a wall — no PR, work preserved, issue labeled by cause — is afkkit doing its job. The failure mode it exists to prevent is pushing a half-broken or wrongly-assumed change all the way to a PR.
- **Idempotent per issue.** Re-running afkkit on an issue whose worktree already exists picks up from it and continues, after the human re-runs `orcakit start <n>` themselves to adopt (rather than recreate) that worktree — the intended path for an issue that was escalated to `needs-planning`, grilled back to `ready`, and re-run.
- **Follow the repo over these defaults.** If a repo has its own review depth, QA location, or PR template, the companion kits already honor those; afkkit doesn't override them.
