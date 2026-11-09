---
name: afkkit
description: >-
  Run a groomed `ready` GitHub issue through the whole build span unattended, covering worktree, implement, commit, QA plan, acceptance check, fix, and open PR, so one issue reaches a reviewable PR with no human at the keyboard. Use when the user says "run issue #N unattended" or "work the ready issues while I'm away". It starts from a groomed issue; planning and grooming stay attended.
license: MIT
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Task, Agent, SendMessage, Skill
metadata:
  internal: false
---

# afkkit

The **away-from-keyboard** runner. Hand it a groomed `ready` issue and it drives the middle of the dev workflow from an isolated worktree to an open pull request: implement and commit, write and run the QA plan, check the result against the issue, fix, open the PR, and flip the issue to `in-review`. The human gates stay where judgment lives: planning and grilling happen *before* (the `ready` label is the entry contract), review and merge happen *after*. Deep code review also happens after: a PR-level review bot covers the diff once the PR opens, so afkkit runs exactly one acceptance check in-span.

afkkit adds **no** worktree, tracker, or PR behavior of its own. It **sequences** companion kits (issuekit `start` at the front, then implementkit, commitkit, qakit, reviewkit, and prkit) and owns exactly one thing they don't: the **escalation policy** that decides, at every step, whether to keep going or stop cleanly and leave the issue for a human.

## The contract

- **Input:** an issue number, or `all`. afkkit invokes **issuekit `start <n>`** itself, and issuekit refuses anything not labeled `ready`, gets the worktree from gitkit (off a freshly resolved base ref, adopting an existing one rather than recreating it), flips `ready → in-progress`, and runs the repo's declared worktree setup through gitkit `prepare`. That guard is the safety property, and it holds no matter who types the command: an issue only reaches `ready` after a human grill session, and afkkit can neither promote an issue to `ready` nor start one that isn't.
- **Authorization:** naming the issue, or the single OK on an `all` queue, is the user's authorization for exactly these actions on each issue: acquire the worktree through issuekit `start`, including the worktree setup the repo declares, write commits on the issue's own branch, push that branch once at the PR step, and open its PR through prkit. afkkit states this authorization to every companion kit it invokes and in every dispatch prompt, and prkit takes it as its preview OK for the QA-plan commit and PR creation. Label writes need no authorization, because their owning skills exempt them for every caller. Any action outside this list still needs consent, so the run [escalates](#the-escalation-contract) on it: a force-push, a rebase of a published branch, a push to another branch, a merge. The one way to widen the list is in writing, in the issue body: an outward action the body pre-approves by name (a grill records these, such as "may file follow-up issues") joins the list for that issue only.
- **Output on success:** an open PR whose body opens with the decisions the run took on the user's behalf, as text under **Assumptions**, then carries any unmet acceptance criteria and a pointer to a committed QA plan holding the automated results, plus the issue moved to `in-review`.
- **Output on a blocked run:** **no PR.** The worktree and its commits stay intact, a comment on the issue names the precise stuck-state, the issue is labeled for whoever must pick it up, and, in a batch, the next issue starts. afkkit never publishes half-broken work: every commit before the PR step runs with commitkit's `no-push`, so the branch reaches `origin` only when prkit opens the PR.

## When this fires

- **one issue.** "afkkit 42", "run #42 unattended", "autopilot issue 42", "take #42 to a PR".
- **the whole ready queue.** "afkkit all", "work the ready issues while I'm away", "drain the ready backlog".

If the user names neither an issue number nor `all`, ask which. afkkit never plans, grills, merges, or responds to PR review feedback (see [Non-goals](#non-goals)).

**Run it from the main checkout, in the session you are already in.** One command does the whole span: issuekit `start` acquires the worktree, and every step works inside it by path. There is no separate session to open in the worktree and no build prompt to type there. A host that can bind a new conversation to a worktree (T3 Code's thread launch is one) may show the run in that conversation, but nothing in the run depends on it.

## Preflight (once per invocation)

```sh
gh --version && gh auth status                          # GitHub CLI installed + authenticated
gh repo view --json nameWithOwner -q .nameWithOwner     # inside a repo on GitHub
```

- If `gh` is missing or unauthenticated, stop and point to `https://cli.github.com` / `gh auth login`.
- **Companion-kit check.** afkkit needs implementkit, commitkit, qakit, reviewkit, and prkit. If a kit a step needs is absent, **stop and name it** rather than improvising its job. (Steps below name the plain `gh` fallback where the action is trivial.)
- **issuekit is required, and has no fallback.** It owns the `ready` guard the whole safety property rests on. If it isn't installed, **refuse the run and say to install it**; never re-implement the guard with `gh`. A second copy of a gate is a gate that can drift open, and the copy inside an unattended runner is the one nobody notices drifting.
- **A GitHub tracker is required too, and that is a separate check.** When the repo keeps no GitHub issues, refuse and name that as the reason, and point at **issuekit** `create` to file the plan first. Say it plainly rather than as a missing-dependency error.
- **No shell / CLI available?** Say so and stop; afkkit is an execution runner and there is nothing to reason out in prose.

**Done when** `gh` is authenticated, every companion kit is present, and the repo keeps GitHub issues, or the run has stopped and named the missing piece.

## How the run executes

**One warm session carries the issue.** Start, spec gate, implement, commit, QA plan, fix, and PR all run in one context, so no step re-derives what an earlier step already read. Every hand-off between agents costs a cold start and a rediscovery, and a run that moves its context between agents at every step pays that cost five times over. A named issue runs in the session the user invoked afkkit in; [Batch mode](#batch-mode-all) gives each issue a session of its own.

- **The worktree path is carried run state, not the session's location.** Hold the path issuekit returns and run every command against it: `git -C <worktree> …`, or `cd <worktree> && …` inside the same shell call. A shell's working directory may reset between calls, and a command that ran in the main checkout by mistake writes to the wrong branch.
- **implementkit decides when implement splits.** Its own conductor rule sends a build with more than one heavy phase, or one mechanical bulk phase, to one subagent per phase group. afkkit adds no second split rule. A session that cannot dispatch (a subagent, on Claude-compatible hosts) builds the groups inline, as implementkit already says.
- **The run makes one dispatch of its own: the [acceptance check](#5-acceptance-check).** It is the only step whose value comes from *not* holding the session's context.
- **Every model is the session's model.** No step routes to another model or family by default. The user can name one inline ("afkkit 42, acceptance check on sonnet"); validate it against the active host, and write the host's alias, never a dated snapshot.
- **Task-tracking tools are not run state.** A harness task list is a fine progress display but it is not durable. `progress.md` and the issue's labels and comments are the record.

### Dispatch rules

These bind every subagent the run starts: the acceptance check, a per-issue agent in a batch, and implementkit's phase-group agents when afkkit is installed.

- **Start a new agent, never a fork.** A forked agent inherits the dispatcher's transcript and can mistake itself for the dispatcher: a reviewer forked from a conductor once decided it *was* the conductor, self-reviewed, wrote "no blockers", and opened the PR itself. A new agent starts with only its brief.
- **The brief names the role and its edge.** Say what the agent is ("you are the acceptance checker for issue 42"), what it returns, and which actions belong to someone else ("do not run QA, commit, push, or open a PR").
- **The brief passes inputs by path.** Give the worktree path and the run-directory files it reads; the agent's first action is to work inside that path. A payload goes in a file, and the return is pass or fail plus the identifiers and one-line summaries the dispatcher needs (`B1 · sidebar absent at 1280 px`).
- **The brief states two command rules**, because a subagent starts without the lessons of the last one. First, write commands that run the same in zsh and bash: quote every glob argument (`--include='*.tsx'`), and iterate a file list with `| while IFS= read -r f` or `xargs`, never `for f in $var`. Second, run each gate command once into a log file, then print its exit code and a bounded tail, and never run it again to get the messages or the pass signal.

**No subagent capability?** Run the acceptance check inline as a self-check, and write `self-check` at the top of `findings.md` so the PR body can say so. The rest of the pipeline is unchanged.

### Work that runs once

Each of these repeated in a measured run, and each repeat bought nothing: `pnpm deps:check` ran 13 times across 9 agents, and one session started its dev server 31 times.

- **One dev server per run.** Start it once with the repo's own script, its output to a log and its PID in a file, and record the start and stop commands in `orientation.md`. Every later step reuses it. Stop it before the [Hand off](#8-hand-off) and confirm the port is free.
- **A red base gate is proven once.** When a gate is red and the session believes `main` is red too, record the claim in `orientation.md`: the command, its exit code, and the failing lines. No step re-runs it to prove the claim again; the [acceptance check](#5-acceptance-check) verifies it once against the base branch.
- **Each gate command runs once per revision, into a log.** A second run on the same commit and the same dirty state produces the same answer at full price.
- **The browser opens in qakit only.** qakit drives the page checks and captures the screenshots; every other step reads its results.

## The run directory

Each step writes its payload down once, in one place, so a resumed run and the acceptance check read the path instead of re-deriving it.

- **Where.** `.afkkit/` at the **worktree root**, excluded from git so nothing in it reaches the PR diff. Register it in the repo's private exclude file:

  ```sh
  git -C <worktree> rev-parse --git-path info/exclude    # resolve the real path first
  ```

  **Ask git for that path; never hardcode `.git/info/exclude`.** In a linked worktree `.git` is a *file*, not a directory. Append `.afkkit/` only if it isn't already listed; the exclude file is shared across worktrees.

- **What's in it.**

  | File | Written by | Read by |
  |------|-----------|---------|
  | `assumptions.md` | [spec gate](#2-spec-gate), then every step that decides something | [Open the PR](#7-open-the-pr) (copied into the PR body as text), the acceptance check |
  | `checks.md` | [spec gate](#2-spec-gate) | qakit, the acceptance check |
  | `orientation.md` | any step that starts the dev server or claims a pre-existing failure | every later step, the acceptance check |
  | `findings.md` | the [acceptance check](#5-acceptance-check) | [Fix](#6-fix) |
  | `progress.md` | every step that lands work, one line each | [Resume an interrupted run](#resume-an-interrupted-run) |

- **`assumptions.md` is the decisions list.** Every time the run picks between two reasonable options on the user's behalf (a file name, a library pin, an edge case the issue left open, a failing test on `main` it worked around), it appends one line: what it chose, the alternative, and why. The gate writes the first entries; implement, QA, and fix append theirs as they happen, never from memory at the end. This list is what the user reads first in the PR.
- **`checks.md` is the yardstick.** One line per acceptance criterion: an identifier, the **observable** that would confirm it, and a flag for whether an agent can confirm it or only a human can, such as `C3 · sidebar visible on /dashboard at 1280 px · agent`. Use qakit's test for the flag: a check whose pass condition a script can assert is the agent's, and with a browser driver on the box that includes what a page shows. It holds no commands; qakit works those out from what shipped.
- **`orientation.md` holds facts with sources, never conclusions.** "`pnpm lint` exits 1 on `main` at `abc123` with 12 errors in `vendor/`" is a fact; "lint is broken anyway" is not. It stays short: the dev-server commands and the pre-existing failure claims, nothing else.
- **`progress.md` lines.** `implement <group> <phases> <sha>`, `qa <path> <sha>`, `check <n blockers>`, `fix <sha>`, `qa-refresh <sha>`. One line per landed step, appended right after the step lands.
- **No writable filesystem?** Hold each payload in the session and paste it into the acceptance check's brief, and say that's what you're doing.

## Resume an interrupted run

Adopting a worktree proves nothing about which steps passed. A usage-limit stop is the common case: a long build hits the session's window, and the next session starts with none of the context. When the issue already reads `in-progress`, or an `issue-<n>-` branch already exists, read the state first, in one call, before any work:

```sh
git branch --list 'issue-<n>-*' && git worktree list --porcelain \
  && gh pr list --state all --json number,url,state,headRefName -q '.[] | select(.headRefName | startswith("issue-<n>-"))'
```

With the worktree path known, add `git -C <worktree> status --porcelain`, `git -C <worktree> ls-remote --heads origin <branch>`, `git -C <worktree> rev-parse HEAD`, and `cat <worktree>/.afkkit/progress.md` to a second call. Then take the first row that matches:

| State found | The run stopped after | Resume at |
|---|---|---|
| an open PR on the branch | PR creation | the `in-review` advance only, when the label still reads `in-progress` (prkit's label step, or `gh issue edit <n> --remove-label in-progress --add-label in-review`); the outcome is **opened** |
| a merged or closed PR on the branch | the span | nothing; report the PR and stop, because issuekit `close` or a human owns it |
| the branch on `origin` at the local `HEAD`, no PR | the push | [Open the PR](#7-open-the-pr) |
| the branch on `origin` at another commit | unknown | escalate keeping `in-progress`, and name both commits |
| uncommitted changes other than the QA plan that `progress.md` names | a step in flight | escalate keeping `in-progress`, and list the paths; afkkit does not guess whose they are |
| a `qa-refresh` line, or a `check 0` line | the last QA write | [Open the PR](#7-open-the-pr) |
| a `fix` line, no `qa-refresh` | the fix commit | the qakit refresh in [Fix](#6-fix) |
| a `check` line with blockers, no `fix` | the acceptance check | [Fix](#6-fix); check each blocker ID against the code before applying it |
| a `qa` line, no `check` | the QA plan | [Acceptance check](#5-acceptance-check) |
| an `implement` line for every phase group, no `qa` | the last phase commit | [QA plan](#4-qa-plan) |
| `implement` lines for some groups | a phase commit | [Implement](#3-implement), from the first group with no line |
| no `progress.md` | nothing afkkit recorded | the full pipeline |

Every commit named in `progress.md` must be on the branch (`git merge-base --is-ancestor <sha> HEAD`). A named commit that is missing means the history moved under the run, so escalate keeping `in-progress`. On every row that resumes inside the worktree, run issuekit `start` first to adopt it, and skip the spec gate when the issue arrived `in-progress` and `assumptions.md` and `checks.md` already exist. An issue that came back through `ready` gets a fresh gate, because a grill changed its spec.

**Done when** the matched row and the resume point are named in one line, before any work.

## The pipeline (per issue)

Run these in order for each issue. Any step that can't proceed hands to [the escalation contract](#the-escalation-contract) and the issue stops there, cleanly, with no PR.

### 1. Start the issue

Invoke **issuekit** `start <n>` and say the run is unattended. afkkit adds nothing to `start` and re-implements none of it: issuekit refuses any issue not labeled `ready`, asks **gitkit** for the worktree (branch `issue-<n>-<slug>`, adopting an existing one rather than recreating it), and flips the label `ready → in-progress`. issuekit previews every mutation and waits for an OK, except its label writes, which run unprompted for every caller; saying the run is unattended tells every later step there's nobody to answer a prompt.

issuekit returns the result of gitkit `prepare` with the path. **A failed prepare is an execution gap**: escalate keeping `in-progress`, and comment the failed command, its exit code, and the output tail. A build in a worktree with no dependencies or no database fails later and further from its cause.

issuekit's open-PR check returns the open-PR count and numbers to an unattended caller. It warns at 3 and never refuses, so the run continues either way; hold the count for the [Hand off](#8-hand-off).

Then verify what came back, as **one** shell call, and hold the path as this issue's run state:

```sh
git -C <worktree> rev-parse --show-toplevel \
  && git -C <worktree> branch --show-current \
  && gh issue view <n> --json labels -q '.labels[].name'   # real worktree, right branch, label now in-progress
```

**If issuekit refuses, that's a preflight stop, not [an escalation](#the-escalation-contract)**, because nothing has happened yet. Report the reason issuekit gave, verbatim, and, in a batch, move to the next issue:

- **`needs-planning`** → the decisions aren't settled; it needs a human grill session first.
- **`blocked`** → name the `Blocked by #N` prerequisite and its state.
- **closed, or carrying no lifecycle label** → say which; issuekit `triage` is what classifies it.

An issue already `in-progress` is **not** a refusal. issuekit takes its adopt path, gitkit hands back the existing worktree, and the run continues from the state [Resume an interrupted run](#resume-an-interrupted-run) finds. That covers a re-run after an escalation, a run cut off by a usage limit, and a worktree a human staged by hand.

**Done when** the verification call prints the worktree root, an `issue-<n>-` branch, and the `in-progress` label, or the refusal reason is recorded.

### 2. Spec gate

One read of the issue body and the code it touches, in the session, before any code exists. It classifies every gap between what the issue specifies and what building it requires:

- **Missing decisions.** Product choices or trade-offs a human would have to make. → **Escalate as a planning gap:** stop before writing any code, comment the exact open questions on the issue (phrased as grill-questions), and flip `in-progress → needs-planning`.
- **Attended work.** A phase that needs a person: one marked `Attended:` in the issue, a human pick such as a design choice or a mockup approval, or an outward action that [the run's authorization](#the-contract) does not cover, such as filing follow-up issues. → **Escalate as a planning gap** the same way: comment each pick or action the run would stop for, and flip `in-progress → needs-planning`. A run that meets one in the middle stops there with work half built, so the gate finds it first. A grill that settles the pick, or pre-approves the action in the issue body, clears it.
- **Missing mechanics only.** File names, minor edge cases, naming, ambiguities a competent implementer fills uncontroversially. → **Proceed**, and write each choice to `assumptions.md`.

A `ready` issue *should* clear this gate, because grilling is what earns `ready`. The gate is the backstop for a decision that slipped through: never build on an un-made decision. implementkit's thin-spec bounce stays as the second line behind it.

**The gate also writes `checks.md`**, one entry per acceptance criterion. Because it runs before any code exists, the yardstick tests what the issue asked for, not what the code happens to do.

**Done when** `assumptions.md` and `checks.md` exist, every acceptance criterion has a `checks.md` entry, and the classification is decided, or the run has escalated.

### 3. Implement

Invoke **implementkit** against the issue spec, with the worktree path and the authorization. implementkit resolves its own straight-through-vs-TDD mode, splits a long build into phase-group subagents under its own rule, and enforces the repo's own test + build gate before it reports done. Two failure shapes route differently:

- implementkit **bounces the spec as too thin** → a *decision* gap the gate missed. Escalate to `needs-planning` with the specific gap commented.
- implementkit **can't get the gate green** → an *execution* failure. Escalate keeping `in-progress`, with the failing gate output commented.

**Commit at every phase boundary.** An issue with `## Phase N` headings commits once per phase group, through **commitkit** with `no-push` (fallback: `git add -- <paths the group changed> && git commit` with a conventional subject from the issue title, and no push), and appends `implement <group> <phases> <sha>` to `progress.md` right after. implementkit's own contract stops short of committing, so afkkit makes the commit between groups. That boundary is what bounds a usage-limit stop: a re-run loses at most the group in flight. A body with no phase headings is one group.

**The run does not tick the issue's phase checkboxes.** The exemptions in this pipeline cover label writes only, and a checkbox edit is not a label write. The commits on the branch are the record while the run is live.

**Done when** every phase group has an `implement` line in `progress.md` whose commit is on the branch, the worktree is clean, and implementkit's gate is green, or the run has escalated.

### 4. QA plan

Invoke **qakit** on the branch, handing it `checks.md` as the acceptance list and the dev server recorded in `orientation.md`. qakit writes `docs/qa/NNNN-qa-<slug>-YYYY-MM-DD.md`, runs every agent-confirmable check itself (in the headless browser when a driver is present), captures a screenshot of each screen a human must judge, and records the revision every result ran against. The human-only entries in `checks.md` become its manual cases.

**One exception escalates here:** if the change **does not run at all** (the app won't start, every page check fails the same way), that is an execution gap. Escalate keeping `in-progress`, and don't pay for an acceptance check of code that can't start.

Leave the QA doc uncommitted; prkit commits it at the PR step. Append `qa <path> <sha>` to `progress.md`.

**Done when** the QA plan exists, every agent entry in `checks.md` has a ✅ or ❌ in it at a named revision, and `progress.md` has the `qa` line.

### 5. Acceptance check

The run's one review, and its one dispatch. Start a **new** subagent under [the dispatch rules](#dispatch-rules), on the session's model unless the user named another. It has no memory of the build, which is the independence it exists for: a reviewer that shares the builder's context shares its blind spots, whatever model it runs on.

Its brief carries, by path: the worktree, the issue number, the branch diff range (`<base>...HEAD`), `assumptions.md`, `checks.md`, `orientation.md`, and the QA plan with its screenshot directory. It says the agent **is** the fresh reviewer, so it runs the passes itself rather than delegating them again. Its job, in order:

1. **Verify every pre-existing failure claim** in `orientation.md`: run each named command once against the base branch, in a throwaway worktree of the base (`git worktree add --detach <tmp> <base>`, removed after), and mark it `confirmed` or `belongs to this branch`. A failure that belongs to the branch is a blocker. This is the one check between an unattended run and a shipped regression, so the agent that built the change never grades it.
2. **Run reviewkit's requirement-completeness and correctness passes only**, against the diff range, with the issue as the stated intent and `checks.md` as the criteria. Read qakit's ❌ results and screenshots as evidence: a criterion the screenshot contradicts ("design A was chosen; the page shows B", "the sidebar is absent") is a blocker even when the diff reads fine. With no screenshots (no driver on the box), review the diff alone and say so in `findings.md`.
3. **Read `assumptions.md` against the issue.** An assumption that contradicts the issue, or decides something the issue reserved for a person, is a blocker.
4. **Write `findings.md`** with **blockers only**, each with a stable ID (`B1`, `B2`), its file and line or check ID, and the evidence. Style, naming, and taste are not blockers; the PR review bot and the human reviewer own them.

The brief ends with the agent's edge: it edits no code, starts no browser, and does not run QA, commit, push, or open a PR. It returns the blocker count and one line per blocker ID. Append `check <n>` to `progress.md`.

**Done when** every pre-existing claim is marked, every agent criterion in `checks.md` has been compared with its QA result, and `findings.md` exists with a blocker list, empty or not.

### 6. Fix

Skip to [Open the PR](#7-open-the-pr) when `findings.md` holds no blockers.

Otherwise, in the session, apply every blocker by ID through **implementkit**'s fix round, which runs the repo's gate. If a blocker cannot be fixed, or the gate won't go green, escalate keeping `in-progress` and name the stuck ID: **no PR opens with a known blocker in it**. A confirmed pre-existing failure is not a blocker, but if it means an acceptance criterion cannot be met from repo state, carry it to the PR body as an unmet criterion.

Commit through **commitkit** with `no-push` and append `fix <sha>`. Then invoke **qakit** again on the same QA plan, which it updates in place. qakit reuses a result only when it names the new revision, so it re-runs what the fix commit invalidated; afkkit does not narrow that rule. Append `qa-refresh <sha>`.

**Done when** no blocker ID survives, the fix commit is on the branch, and the QA plan names the new revision, or the run has escalated with the stuck ID.

### 7. Open the PR

Invoke **prkit** with [the run's authorization](#the-contract), handing it paths: `assumptions.md`, the QA-plan path, any **unmet acceptance criteria**, and `findings.md` when the acceptance check ran as a self-check. Tell prkit to copy the `assumptions.md` entries into the body as text under an **Assumptions** heading and to put that section **first**, above the summary: these are the decisions the run took for the user, and the reviewer reads them before anything else. Never link the file, because `.afkkit/` is excluded from git and a reviewer cannot open it. prkit writes the title and body from the real commits and diff, commits the QA plan, pushes the branch for the first time, opens the PR, and advances the issue to `in-review`. The authorization covers the QA-plan commit, the push, and the PR, so none of them stops at a preview. **That advance runs unprompted** under prkit's own label exemption. Only if prkit is absent does the run fall back to `gh issue edit <n> --remove-label in-progress --add-label in-review` after opening the PR by hand.

This step is mechanical: its inputs are the run-directory files and the diff, and it explores no code.

This is the successful terminus: an open PR, a committed QA plan, and an `in-review` issue.

**Done when** the PR URL exists, the QA plan is among the PR's commits, the body opens with the assumptions as text, and the issue reads `in-review`.

### 8. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Nobody watched this run, so the report is the handover. Stop the dev server first, and confirm its port is free.

**What changed.** Give one outcome line for the issue: **opened** (PR link), **escalated** (which label, one-line reason, issue link), or **skipped** (issuekit refused it, with the reason, and the fact that nothing was mutated). Then list every `assumptions.md` entry, one line each: these are the decisions the run took for the user. When the start returned 3 or more open PRs, add one line with the count and the PR numbers, so the user sees the review queue grow. In a batch, accumulate the outcome lines for the batch summary.

**Where it landed.** Give the worktree path and branch. On an escalation this is load-bearing: the commits are real work on disk. A skipped issue has no worktree; say that plainly.

**Next.** Route by outcome, naming a sibling kit only when it's installed and otherwise describing the action plainly:

- **opened** → the PR needs a human reviewer. **mergekit `start <n>`** pulls it down into the worktree it was built in; the manual cases of the committed QA plan are what they run by hand. Give the path to qakit's gallery, `~/qakit/<plan file name without .md>/index.html`, which shows each case's screenshots.
- **escalated to `needs-planning`** → run a grill session with **grillkit** on the issue's open questions. Then promote the issue back with **issuekit** `triage`, which flips `needs-planning → ready` on your word after the grill, and re-run afkkit.
- **escalated, still `in-progress`** → execution is stuck. Point at the commented gate output or surviving blockers; pick it up in the existing worktree by hand.

Crown **one** next move even after a batch, usually the oldest open PR. Route, don't launch: afkkit never invokes mergekit or grillkit itself.

**Done when** each issue has one outcome line and a worktree path or a stated absence of one, every assumption is listed, no process the run started is still running, and the report names exactly one next move.

**Metrics print only on request.** When the invocation asks for them ("afkkit 42 with metrics"), print one table per issue: one row per step (a per-group implement dispatch names its phases), with time, tool uses, tokens, and cache read/write columns **only where the harness actually reports them**. Never estimate a number; the table exists to compare runs against each other. The metrics live in the report and nowhere else; afkkit writes no run-report artifact.

## The escalation contract

The one policy afkkit owns. Whenever a step can't proceed, **escalate** rather than push forward.

**A pre-existing failure claim is verified by someone other than its author.** A step that reports a gate as red-but-already-broken is asking to be excused from the one check between an unattended run and a shipped regression, and a failure it caused and a failure it inherited look identical from inside the worktree. The session records the claim in `orientation.md` and keeps building; the [acceptance check](#5-acceptance-check) re-runs it on the base branch:

- **The base is green.** The failure belongs to this branch. It is a blocker, and [Fix](#6-fix) owns it.
- **The base is red as well.** The claim holds, and the run continues. But if the failure means an **acceptance criterion cannot be met from repo state**, that goes into the PR body as an explicit unmet criterion. Read the QA plan's result for that criterion before deciding it is unmet; don't infer it from a failing gate.

**A step that needs consent, with nobody to ask, escalates.** A step that reaches a preview-and-confirm gate for an action outside [the run's authorization](#the-contract) stops rather than assuming a yes: keep `in-progress`, comment what the step was about to do, and move on. Two kinds of mutation run without a prompt. The first is an action the authorization names, which the user approved when they started the run. The second is a mutation the owning skill exempts for **every** caller: issuekit `start`'s `ready → in-progress` flip and prkit's `in-review` advance both run unprompted. afkkit relies on the exemptions the owning skill already wrote and never widens one, and it never stretches the authorization past its list.

Then escalation always means the same five things:

1. **No PR.**
2. **Keep the work.** Leave the worktree and every commit intact, and stop the dev server.
3. **Comment the stuck-state** on the issue, precisely: the open questions for a planning gap, the failing gate output for an execution gap, the surviving blocker IDs for a review gap. On a multi-phase issue, name the phases that committed and the phase that stopped.
4. **Set the label by *cause*.** A **planning gap** (a missing *decision*, from the [spec gate](#2-spec-gate) or implementkit) → flip `in-progress → needs-planning`; it goes back to the human's grill queue. An **execution gap** (tests won't go green, or blockers survive the fix) → **keep `in-progress`**; the spec was fine.
5. **Continue the batch.**

**Done when** the issue carries the stuck-state comment and the label its cause sets, and the worktree still holds every commit.

## Batch mode: `all`

`afkkit all` takes its queue from `gh issue list --label ready --json number,title,labels,updatedAt` and walks it **sequentially**. Sequential is deliberate: implement dominates the wall clock and is irreducibly serial, parallel branches off one base make merge conflicts unpredictable, and parallel sessions share one usage budget and stall each other into session limits.

**The invoking session becomes a thin conductor, and each issue gets a new agent.** Issue N's context must never bill issue N+1's turns, so the conductor holds only the queue and each issue's one-line outcome. Per issue:

1. **Dispatch an issue agent** under [the dispatch rules](#dispatch-rules). Its brief is the issue number, the authorization, and this skill: run the [pipeline](#the-pipeline-per-issue) from [Start the issue](#1-start-the-issue) through [QA plan](#4-qa-plan) and return the worktree path, the open-PR count, the outcome so far, and the `progress.md` tail.
2. **Dispatch the [acceptance check](#5-acceptance-check) from the conductor.** On Claude-compatible hosts a subagent cannot start a subagent of its own, so the issue agent cannot make this dispatch. The conductor can, and the checker stays independent of the agent that built the change.
3. **Continue the issue agent** with the blocker count and the `findings.md` path, using the host's message-to-agent tool (`SendMessage` on Claude-compatible hosts, `send_input` on Codex), so it keeps its warm context through [Fix](#6-fix), [Open the PR](#7-open-the-pr), and [Hand off](#8-hand-off). On a host that cannot continue an agent, dispatch a new one from the resume table's row instead.

The conductor **never writes to a worktree**. It dispatches, reads `progress.md` and the labels to verify a claim, and decides the next move. Between dispatches it says what it is doing in one line.

- **Order the queue by priority.** issuekit's priority labels come back in the same `labels` array: highest first, then oldest-updated within a level, unassessed last. Fall back to oldest-first when no issue carries a priority, and say so in the preview. An explicit order the user names beats both. **Priority orders the queue and relaxes nothing**: a `critical` issue still needs `ready`, still faces the spec gate, and still escalates rather than guessing.
- **One confirmation, up front.** Print the queue (number, priority, title, in walk order) and wait for a single OK before starting anything. Above the queue, print how many feature PRs the user already has open (issuekit's open-PR check, run once here), because every issue in the queue adds one more; at 3 or more, say so. The OK covers it, and the issues then start without the per-issue question. After that OK the run is unattended: no further prompts, whatever happens. A single-issue invocation needs no confirmation, because naming the number *is* the intent.
- **The queue is fixed at that OK**, never re-read before each issue. The run mutates labels as it goes, so re-reading would drain issues nobody approved.
- **Issues start just in time**, each at the top of its own pipeline run: the worktree branches off a freshly fetched base, and a batch that stops early leaves unreached issues untouched in `ready`.
- **`all` drains `ready` only.** An issue already `in-progress` may have a human in its worktree, so the batch passes over it; name it explicitly (`afkkit 42`) to include it. **`stacked` issues are passed over too**: a batch cannot safely chain them, because one bad bottom layer poisons every layer above it. **List both kinds in the up-front preview with their priorities and say why they were skipped**; silence reads as "unworkable" when the truth is that only this runner declines them.

At the end, print the **batch summary**: PRs opened (with links), escalations by state (with links and one-line reasons), skips and why, the assumptions each opened PR carries, and, when the run didn't finish the queue, **which issues it never reached, with their priorities**. Then give the single crowned next move from [Hand off](#8-hand-off). That summary plus GitHub's own notifications is the whole signal surface.

## Non-goals

- **No planning or grilling.** A thin spec goes back to the human queue as `needs-planning`. plankit and grillkit stay interactive.
- **No second review round in-span, and no style review.** The run checks once, against the issue; deeper review belongs to the PR-level review bot and the human reviewer after the PR opens.
- **No PR-feedback loop, no merge, no teardown.** The span ends at PR open. issuekit `close` runs after merge, out of span.
- **No parallel batches, no push notifications.** Browser checks happen only inside qakit. GitHub plus the session summary are the only signal.
- **No stack chain-draining.** `all` skips `stacked` issues and says it did; a named `stacked` issue runs like any other because issuekit's guard verifies the prerequisite's PR itself.
- **No new worktree, tracker, or PR logic.** gitkit owns the worktree lifecycle, issuekit owns the tracker vocabulary and the `ready` guard, prkit owns the PR. afkkit sequences them and owns the escalation policy. Invoking a gate is not owning one: the moment afkkit would have to decide *whether* an issue is workable, it has left its span.
- **No config file.** Every step runs on the session's model, and a spoken inline override is the only routing surface.

## Notes

- **Escalation is a success, not a failure.** Stopping cleanly at a wall, with no PR, work preserved, and the issue labeled by cause, is afkkit doing its job.
- **Idempotent per issue.** Re-running afkkit on an issue whose worktree exists adopts it through issuekit `start` and resumes from the state it finds, per [Resume an interrupted run](#resume-an-interrupted-run).
- **Follow the repo over these defaults.** If a repo has its own review depth, QA location, or PR template, the companion kits already honor those; afkkit doesn't override them.
