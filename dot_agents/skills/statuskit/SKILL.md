---
name: statuskit
description: >-
  Survey a project read-only (working tree, issues and their priority, open PRs, unfiled plans) into a one-screen dashboard that crowns one finish-first next move routed to the kit that does it, saved by default as a throwaway snapshot under docs/status/. Use when you sit down at a project and ask "what should I do next" or "check project status"; add "no file" to skip the snapshot. It reads and recommends only; the crowned kit does the work.
license: MIT
allowed-tools: Bash, Read, Write, Edit, Skill
metadata:
  internal: false
---

# statuskit

The front door you open when you sit back down at a project and ask *"where is this thing, and what's my single best next move?"* statuskit surveys the whole project **read-only**, covering the git working tree, GitHub issues, open PRs, and unfiled plans, prints a one-screen **status dashboard**, then does the opinionated part: it ranks the possible next actions by a **finish-first** rule and crowns exactly **one** as the move to make, routing you to the kit (or plain command) that does it.

It is a **read + advise** tool. It never commits, pushes, closes an issue, edits a PR, merges, relabels, or writes code, because every mutation happens inside the kit it hands you off to, under that kit's own guard. Nothing it does reaches a remote, a branch, or a tracker, and that is the point: statuskit is safe to run anytime, as often as you like, to re-orient. It writes only the local files its [write rules](#write-rules) list.

## When this fires

You want to orient before acting: "what should I do next", "check project status", "where's this project at", "what's next", "project status", "orient me", "/statuskit", or a bare "what's the state of this" after stepping away.

One boundary matters:

- **Not the tracker authority.** That's issuekit. statuskit reads issue *counts and state* to inform its recommendation and computes one cheap staleness signal. Detailed tracker health belongs to issuekit: issuekit answers "is my tracker honest?"; statuskit answers "where's this project and what do I do next?"

## The ranking principle: finish-first

Everything statuskit crowns derives from one rule, **"stop starting, start finishing"** (minimize work-in-progress). The crowned move is always whatever retires the most in-flight work for the least effort, *before* anything new is started.

Ties within a rung break on **declared priority first, then one of two signals**, depending on what the rung asks you to do:

- **Resume or finish rungs.** Crown the **most-recently-active** candidate (issue/PR `updatedAt`, or a branch's last-commit time). Recency is a proxy for context-switch cost, and switching cost is what you're minimizing when there's a half-built thing to switch back into. The one exception is a finished-but-unreviewed PR: there's nothing to switch back into, so it breaks on leverage like a start rung does.
- **Start-something rungs.** Crown the highest **unblock leverage** (below), falling back to recency. Starting fresh means there's no context to preserve, so the cost recency measures is zero and the thing worth maximizing instead is throughput: how much work the repo can run in parallel after this one lands.

The rest become runners-up. Neither priority nor leverage promotes a candidate *across* rungs, because finish-first is the spine and both only order within it. **One exception, and only one: a `critical` issue.** See below.

## Priority

**Priority is a human's declared answer to "what matters," read off the [issuekit label set](#the-priority-scale): `critical`, `high`, `medium`, `low`.** Everything else statuskit ranks on is inferred from the repo's mechanics; this is the only signal where somebody actually said it, and that makes it the first tiebreak everywhere rather than a competitor to the ones already here.

### The priority scale

| label | means | how it ranks |
|-------|-------|--------------|
| `critical` | drop everything; preempts work already in progress | promotes across rungs |
| `high` | do this before other workable issues | orders within a rung |
| `medium` | normal priority, the default once assessed | orders within a rung |
| `low` | worth doing eventually; never preempts anything | orders within a rung |
| *(none)* | unassessed; nobody has ranked it | sorts below `low` |

**Priority is one of two independent label namespaces, and statuskit reads both.** Lifecycle (`ready`, `blocked`, `in-progress`, …) says whether an issue *can* be worked; priority says whether it *should* be worked next. Never derive one from the other: a `critical` issue that's `blocked` is still blocked, and crowning it would send the user at something they cannot start.

**Unassessed sorts below `low`, and that isn't a judgment about the work.** It's a judgment about the *tracker*: an issue nobody ranked carries no claim, and statuskit's whole job is to crown a move it can defend. Ranking an unlabeled issue above a labelled one would mean inventing the claim on the user's behalf. When the unassessed pile is large, that's the finding, so surface it and point at `issuekit triage`, rather than quietly sorting a backlog nobody has ordered.

### `critical` is the one thing that outranks finish-first

Every other signal here orders *within* a rung, and that restraint is deliberate, because it's what stops a clever number from talking the user out of finishing what they started. `critical` is the exception, and the argument for it is narrow enough to state in one line: **finish-first is a heuristic for what to do when nobody has said what matters, and `critical` is somebody saying it.**

Minimizing work-in-progress is the right default precisely because it needs no information: it works on any repo, on any day, without asking anyone. A `critical` label is strictly better information than that default, and it is the only signal in the whole survey that a human deliberately put there. Refusing to act on it would leave statuskit ranking a half-built refactor above the thing its own user flagged as on fire, which is the one outcome that would make the dashboard untrustworthy rather than merely wrong.

Three guards keep the exception from swallowing the rule:

- **Only a *workable* `critical` promotes.** It must be unblocked and open, because a `critical` that's `blocked` has nothing to act on, so it stays in the blocked table where it belongs, and the crowned move is its blocker if that blocker is itself workable.
- **`critical` promotes; nothing else does.** `high` is not a small `critical`. It orders within a rung like leverage does, and a repo that wants preemption has to say `critical`, which is exactly the friction that keeps the level meaningful.
- **Say what's being set down.** When a `critical` preempts a rung that would otherwise have won, name the displaced move in the same breath: *"#12 is critical, so it goes first; your red PR #34 drops to the runner-up"*. A preemption the user can't see is indistinguishable from a ranking bug, and this one is rare enough that it should read as an event.

**When more than one `critical` is workable, that's the finding.** Two is a tiebreak (fall through to leverage, then recency), but a tracker where several issues all preempt everything has lost the level: nothing is being dropped for any of them, so `critical` has quietly become the new normal. Say so on the crowned move and point at `issuekit triage`, which flags stale `critical` labels as drift.

## Unblock leverage

**`unblocks(X)` is the number of open issues that become *fully workable* the moment X lands.** It's the answer to "which of these frees the most independent work next," and the file surfaces it as a sortable column on the two tables that already name names.

The word *fully* carries the rule. If #19 is blocked by both #12 and #23, closing #12 alone doesn't make #19 workable; it makes it less blocked, which is worth nothing to somebody looking for something to pick up. An issue counts toward `unblocks(#12)` only when removing #12 leaves its open-blocker set **empty**. Any looser definition inflates the number and points you at the wrong issue, which is worse than not ranking at all.

Leverage flows to PRs through what they close: `unblocks(PR #34)` is the leverage of the issues in its `closingIssuesReferences`. That's what turns the `Closes` column from a fact into a priority, because a review that frees three issues outranks one that frees none, whatever their CI says.

**`closingIssuesReferences` is empty on every stack layer, and that is a platform rule rather than a missing link.** GitHub resolves a closing keyword only on a PR that targets the repository's **default branch**, so a layer PR carrying a correct `Closes #123` reports no closing issues at all until the layer below merges and GitHub retargets it to trunk. Three reads share the field, so all three go wrong together on a layer: the PR closes nothing, so it shows no priority, carries no leverage, and its branch maps to no issue. **So on a PR whose `baseRefName` is not the default branch, fall back to a `Closes #N` scrape of the body** and treat what it finds exactly as `closingIssuesReferences` would have been treated. The scrape stays the weaker read it is everywhere else in this file: spend it only on a layer, and only when the field came back empty.

Four rules keep the number honest:

- **Depth 1 only.** Don't count cascades. A transitive number assumes the intermediate issue gets *finished* rather than merely unblocked, which is a schedule prediction statuskit has no business making, and depth-1 is naturally cycle-safe where a transitive walk needs a guard against `A blocked by B blocked by A`.
- **Only still-open blockers count**, the same rule the blocked set already follows.
- **A blocker may be a PR.** Issue and PR numbers share one namespace on GitHub, so `blockedBy: #34` can mean "waiting on a merge," and it resolves against the open-PR read.
- **No declared dependencies means no column.** When the repo's graph has no edges at all, every value is 0 and the column actively lies: it reads as "nothing unblocks anything" when the truth is "nobody wrote it down." Drop the column, say it once (*no dependencies declared; leverage unavailable*) and point at **issuekit**, because declaring them is tracker hygiene, not a survey's job.

Two states are **surfaced but never crowned**, because acting on them is a human gate, not a finish-first win statuskit should push:

- an approved + CI-green PR ("ready to merge"), because merging is your call;
- a PR whose review someone else actually owes you, which is out of your hands.

Both appear in the dashboard as facts; neither becomes the #1 move.

**"Out of your hands" is a claim about a person who exists.** That second state holds only when somebody has genuinely been asked: a requested reviewer, or a non-author who already reviewed. Inferring it from authorship instead ("you opened it, so you must be waiting on someone") is the assumption that breaks the whole dashboard on a solo repo: every PR is yours, nobody was ever asked, and every row reads *waiting on them* in perpetuity while the ladder crowns something else. So read the wait off `reviewRequests` and `latestReviews`, never off `author`, and when the answer is *nobody*, the PR isn't out of your hands at all. It's stuck on you, and it ranks on the [full ladder](#3-rank-and-crown-one-finish-first-move).

**statuskit crowns the review, never the merge.** That's what keeps the new rung from contradicting the rule above it: reviewing an unreviewed PR is real work with an observable finish, while pressing merge is the judgment call statuskit stays out of. The crowned move ends at *reviewed* and hands the merge decision back to you.

## Resolving the tracker

**Not every project manages its work in GitHub Issues, and `gh` working is not evidence that this one does.** A repo can have `gh` authenticated, Issues enabled, and forty open bug reports, while every planned change lives in Linear. Another can have zero issues because it was created yesterday. Those two want opposite advice, so statuskit resolves the question explicitly instead of inferring it from whether the API answered.

Take the first rung that gives an answer:

1. **The prompt.** The user said so ("we don't use GitHub issues", "file this in the tracker"). Explicit always wins.
2. **The repo's agent-guide file** (`CLAUDE.md` or an equivalent) states where work is tracked. A sentence like *this project tracks work in Linear, not GitHub Issues* settles it in either direction.
3. **Detection**, from the `gh issue list --state all` call [the plans survey](#2-survey-collecting-signals-read-only) already makes, so it costs nothing extra. A non-empty array means **present**. An error that says Issues are disabled on the repo means **absent**.
4. **Unknown.** An empty array, or any other error (network, authentication, rate limit). An empty array cannot tell a day-one repo from a Jira shop, and a failed call says nothing about policy at all.

The reading is one of four states, and every tracker-dependent rule in this file keys on it:

| reading | comes from | issue rungs (†) and Issues panel | unfiled-plan check |
|---|---|---|---|
| **present** | the prompt, the guide, or a non-empty array | run | runs |
| **absent** | the prompt, the guide, or Issues disabled | skipped | skipped |
| **unknown** | an empty array, or any other query error | skipped, and said once | skipped |
| **unavailable** | `gh` missing or unauthenticated, or no GitHub remote | the git-only ladder runs instead | skipped |

*No tracker* below means absent or unknown. **A query error is never absent.** Name the failed call once on the Issues line and route like no tracker; a retry, not a declaration, settles it. The same holds when the prompt or the guide says present and the issue query fails: the policy is known, the data is not, so the issue rungs skip and the failed call is named.

**Unknown routes like no-tracker and says so.** It never asserts a plan is unfiled, never crowns "go file issues", and names both paths in one line. An empty-array unknown is the only ambiguous policy state. When it fires and a user is there to answer → read [declaration.md](declaration.md), then follow it.

**Only statuskit resolves this.** It is the skill that must, because it crowns exactly one move. Every other skill either carries the one-line conclusion (issuekit, afkkit) or names both destinations without resolving anything (plankit, grillkit, implementkit). Keeping the derivation in one place is what stops four skills drifting into four slightly different answers.

## Procedure

### 1. Preflight, degrading per source and never failing wholesale

statuskit is **git-first**: git signals always drive it, and GitHub signals enrich it when available. Detect what's present and adapt, rather than bailing:

- **Not a git repo** → say so; skip everything git-derived. If there's no repo yet, the move is "start with `plankit`."
- **`gh` missing / unauthenticated / no remote** → drop to the **git-only ladder** below. This is a first-class mode, not an error, so name the actual gap once (`gh` is not installed, run `gh auth login`, or add a GitHub remote) and carry on.
- **`gh` usable, but the project doesn't track work in GitHub Issues** → resolve it explicitly, per [Resolving the tracker](#resolving-the-tracker). This is a policy fact rather than a capability one, so it never falls out of a failing call, and the issue rungs and the Issues panel both turn on it.
- **No plan docs** → skip the plans read entirely. The Plans panel is conditional even when plans do exist; see [the plans survey](#2-survey-collecting-signals-read-only).
- **No shell at all** (e.g. a browser-based agent) → you can't run the survey; print the commands below for the user to run and reason from what they paste back.

### 2. Survey, collecting signals read-only

Gather git always; gather GitHub only when `gh` is usable. All commands are read-only.

**git (always):**
- working tree: `git status --porcelain`, current branch, upstream ahead/behind, `git log @{u}.. --oneline` (unpushed; skip if the branch has no upstream set, which is itself the "push/publish" signal), `git stash list --format='%h %gd %s'` (the SHA is the stash's stable identity), and any local branches carrying unmerged commits.
- **the base branch**, from **gitkit**, not an assumption that it's `main`. Every "is this a feature branch?" and "is it unmerged?" judgment below turns on it, and on a `develop`- or `trunk`-defaulted repo, assuming `main` misreads the whole dashboard.
- **branch → issue mapping.** Resolve the current branch to a tracked issue from its open PR's `closingIssuesReferences` (the reliable signal, and already in hand from the PR read below); fall back to a branch-name heuristic. **On a stack layer that field is empty**, so apply [the layer fallback](#unblock-leverage) and read the `Closes #N` from the PR body before you drop to the branch name. **The branch-name pattern comes from gitkit**, which named the branch in the first place (`issue-<n>-<slug>`), so read it there rather than keeping a second copy of the parser here, or a rename upstream leaves this one silently matching nothing. A bare `#N` or a slug matching an issue title are the looser fallbacks. When it stays unmappable, treat a dirty branch that isn't the base as *continue*, not *commit*.
- **worktrees.** When the survey needs to know where a branch's code lives, ask gitkit rather than reading paths. statuskit never creates or removes one; it only reports.

**GitHub (only when `gh` is usable):**
- issues: `gh issue list --state open --json number,title,labels,updatedAt,blockedBy,blocking`, bucketed by lifecycle label (`in-progress` / `ready` / `stacked` / `needs-planning` / `blocked` / `in-review`) plus an **unlabeled/other-status** bucket for repos without that vocabulary. Counts and the actionable set only, with no drift detection. Treat recent unlabeled issues as candidates for classification or planning, not as invisible work.
- **[priority](#priority)**, read from that same `labels` array, so it costs **no extra call**: the survey is already fetching every label on every open issue, and priority is four of the names in it. Take the highest when an issue carries more than one (a tracker slip, not a state, which `issuekit triage` repairs), and `none` when it carries none. **When no open issue carries any priority label, drop the column** rather than printing a wall of blanks, and say it once (*no priorities set; ranking on leverage and recency*) pointing at **issuekit triage**. This is the same rule the all-zero leverage column follows and for the same reason: a column whose values never vary reads as a fact that was checked and came back empty, when the truth is that nobody has filled it in yet.
- **the dependency graph.** `blockedBy` and `blocking` from that same call are GitHub's **native** issue dependencies, so the graph arrives already resolved: no body scraping, no per-issue fetch, no second round trip. Read them defensively (`(.blockedBy // []) | length`) rather than assuming a field layout, and when a repo doesn't use the feature fall back to the text convention, meaning a `Blocked by #N` / `Depends on #N` / `Blocks #N` line in the body, extracted in the shell with `--jq` so bodies never enter context. Both directions describe the same edge; normalize to one.
- **the unblocked set**: every open issue that is neither blocked nor `in-review`, kept as number + bucket + **priority** + `updatedAt` + **`unblocks` count** + title rather than folded into a count. This is the pick-up-now list, and the dashboard prints it as a table so you can act on one without a second `gh` call. An issue is blocked when it has a still-open `blockedBy` entry, or carries the `blocked` label. It is `in-review` when it carries the `in-review` label, because its code is already written and its next move is a review, which the waiting-for-review table below names in full, so repeating it here would pad the pick-up-now list with the one thing you cannot pick up. **A still-open `blockedBy` whose blocker has an open PR does not count as blocked.** That prerequisite is built and pushed, so the dependent can be worked right now on a branch stacked on the blocker's, and it belongs in this table with a `stacked` marker rather than in the blocked set. The open-PR read this dashboard already performs is what settles it, so the check costs nothing extra. Getting this wrong is expensive in one direction only: filing stackable work under "blocked" hides it in the one table a reader is told to skip, which is the exact opposite of what this survey is for. Everything else is unblocked: `ready`, unlabeled or needs-planning, and `in-progress` work you can resume. **Sort by priority descending, then `unblocks` descending, then most-recently-updated**, because a declared priority outranks an inferred one, leverage orders what nobody ranked differently, and recency survives as its own column rather than as the sort order.
- **the blocked set**, the other half of that same read, kept as number + **priority** + what it's waiting on + title. It holds only genuine waits, meaning a prerequisite that has *not* been built; anything whose blocker has an open PR has moved to the unblocked table above. Priority earns its place here even though nothing in this table can be picked up, because it's what tells you whether the *blocker* is worth chasing: a `critical` sitting behind an unstarted prerequisite is the strongest argument in the whole dashboard for starting that prerequisite, and without the column it looks like any other waiting row. The blocker comes from `blockedBy` when it's there, a `Blocked by #N` / `Depends on #N` line when it isn't, and is unnamed when all you have is the bare `blocked` label. Keep all three forms; an unnamed blocker is still a fact worth printing. Reporting what an issue *says* it's waiting on is a fact read, not a tracker verdict, and the moment you're judging whether that blocker is still real, you've crossed into issuekit and should be pointing at it.
- open PRs: `gh pr list --json number,title,author,baseRefName,statusCheckRollup,reviewDecision,reviewRequests,latestReviews,isDraft,updatedAt,closingIssuesReferences`, classified into *your red / change-requested PR* (actionable), *nobody is reviewing it* (actionable), *approved + green* (surface-only), and *genuinely awaiting someone else* (surface-only). Cap the list on large repos to stay fast; if a JSON field is rejected, check `gh pr list --json` with no value, which prints the field list your `gh` accepts.
- **what each PR closes**: `closingIssuesReferences` from that same call, not a `Closes #N` scrape of the body. It's GitHub's own resolved linkage, so it covers `Closes` / `Fixes` / `Resolves` in any casing and issues linked by hand in the UI, and it can't be fooled by the phrase appearing in a code block or a quoted review comment. **The one exception is a stack layer**, where GitHub leaves the field empty by design and [the layer fallback](#unblock-leverage) applies: `baseRefName` is already in the call above, so compare it against the default branch, and on a PR that fails that test scrape `Closes #N` out of the body with `gh pr view <n> --json body --jq` so the body never enters context. Print such a row's `Closes` cell as the issue number followed by `(stacked)`, so a reader sees the link is pending rather than absent, and let priority and leverage flow from it exactly as they would from the resolved field.
- **the waiting-for-review set**: every open non-draft PR whose review is still outstanding (`reviewDecision` empty or `REVIEW_REQUIRED`), kept as number + **what it closes** + **priority** + **`unblocks` count** + CI state + author + **whose move it is** + `updatedAt` + title, in that order, since the ID and the work it retires belong side by side, because together they're the whole reason to care about the row. Sort by priority descending, then `unblocks` descending, then most-recently-updated, the same way the unblocked set does.
- **a PR's priority is the highest priority among the issues it closes**, the same way leverage flows to PRs through `closingIssuesReferences`, and for the same reason: a PR has no importance of its own, only the importance of the work it retires. Take the highest rather than an average, because merging the PR delivers *all* of those issues and the most urgent one is what's actually waiting. A PR that closes nothing has no priority, so print a dash and let leverage and recency order it. The dashboard prints these as a table, because "3 awaiting review" tells you nothing about which one is yours to nudge and which is somebody else's to answer.
- **whose move it is: read it off the reviewers, never the author.** Three outcomes, checked in this order: you appear in `reviewRequests` → **yours**, go review it; somebody else appears in `reviewRequests`, or a non-author appears in `latestReviews` → **theirs**, name them, you're genuinely waiting; neither → **nobody is reviewing it**, which is a stuck PR wearing a waiting PR's clothes. That third case is every PR on a solo repo and a routine slip on a team one (you opened it and never requested anyone), and both have the same shape, meaning no review is coming unless you do something, so it's the only one of the three that ranks.
- **is anyone else even able to review?** Asked only when that third case fires, and only once per run: `gh api repos/{owner}/{repo}/collaborators --jq 'length'`. Exactly one collaborator proves no other reviewer exists, so the move is self-review outright. More than one, or a 403, an error, any answer you didn't get, means you can't rule a reviewer out, so the move names both halves ("request a reviewer, or self-review it"). Never spend the call when no PR needs it, and never let its failure cost you the row: the whose-move column is already correct without it, and the probe only sharpens the wording of the recommendation.
- **stale-tracker signal**, one cheap cross-check: how many merged PRs have a linked issue still open. A single count, used only to decide whether "reconcile" ranks. **Never itemize which or why**, because that's issuekit's job.

**plans (filesystem, where the list always runs and the unfiled check needs a tracker):**
- list canonical `docs/plans/NNNN-plan-<slug>-YYYY-MM-DD.md` files, and the older `plan-<slug>-YYYY-MM-DD.md` shape without the serial, (or wherever the repo keeps plans, since an `rfcs/`, `specs/`, or documented location takes precedence). The list is free and always runs; it's what the ladder's plan rungs read.
- **the unfiled set, computed only when the repo actually tracks work in GitHub issues.** Cross-check each plan against the issue list and keep the ones that never became an issue. Match over **`--state all`**, not the open-issues read the rest of the survey uses: `gh issue list --state all --json number,title --limit 200`, one call, spent only when plan docs exist. A plan that shipped months ago has a *closed* issue, so matching against open issues alone would report every finished plan as neglected, which is the failure mode that makes this panel worth suppressing in the first place.
- **That same call is [rung 3 of the tracker resolution](#resolving-the-tracker), so it costs nothing extra.** Only a **present** reading makes the unfiled comparison meaningful, so on absent, unknown, or unavailable skip it and never report a plan as unfiled. A query error is unknown, not absent. Plenty of projects track work in Linear, Jira, a `TODO.md`, or somebody's head; a survey that announces "18 unfiled" on one of them is reporting its own blind spot as a finding, and pointing the user at `issuekit create` for a tracker they deliberately don't use.
- **Match on the plan's slug and its title, and when the match is uncertain call it filed.** An issue whose title matches the plan's title, or whose body links the plan's path, or whose slug matches, is enough on its own. The asymmetry is deliberate: this panel only ever prints gaps, so a false negative costs one silent line and a false positive sends the user off to file a duplicate of work already tracked.
- **the unbuilt set, which is what the plan rung ranks when there is no tracker.** Find phases by a heading beginning `Phase <n>`, matching the separator loosely (`### Phase 2: auth` and `### Phase 2 — auth` are the same shape, and real plan sets carry both). A phase is **built** when its heading carries a `(built YYYY-MM-DD)` stamp, which **implementkit** writes into the same trailing slot issuekit's `(#41)` occupies; the two coexist, so `### Phase 2: auth (#41) (built 2026-08-20)` is a tracked phase that shipped.
- **A plan with no stamp anywhere makes no claim.** The stamp convention is opt-in per plan, so absence means unstamped rather than unbuilt, and reading it as unbuilt would report every plan written before the convention as outstanding work. Treat such a plan as a single unit and crown it whole, exactly as [the git-only ladder](#3-rank-and-crown-one-finish-first-move) already does. Once a plan carries one stamp it is authoritative, and its unstamped phases are genuinely unbuilt. A fully stamped plan is finished, so drop it.

### 3. Rank and crown one finish-first move

Map the signals onto candidate actions, each tagged with its owning kit/command, then crown the highest applicable rung. Ties inside it break as the rung's own row says, defaulting to most-recently-active, and everything else becomes a runner-up. Pick the ladder by whether GitHub signals are available.

**Git-only ladder** (no `gh`):

| # | State | Move → |
|---|-------|--------|
| 1 | uncommitted work on a feature branch | continue, or run `commitkit` |
| 2 | unpushed commits | `git push` |
| 3 | a stash | inspect and restore it with `gitkit rescue`, or drop it |
| 4 | an unmerged local feature branch | finish it, or clean it up with `gitkit clean` |
| 5 | a plan doc on disk, where filed or not is unknowable with no tracker to check | implement the newest with `implementkit` |
| 6 | clean on the base branch, nothing pending | start something (newest plan), or run `plankit` |

**Full ladder** (`gh` available), where every git-only state has an explicit home below. *(Surfaced, never crowned: an approved+green PR; a PR someone else genuinely owes you.)*

| # | State | Move → |
|---|-------|--------|
| 0 † | a **workable `critical`** issue that is open, unblocked, and not already the crowned move | drop what you're on: `issuekit start <N>` if it's `ready` or startable `stacked`, resume it if it's `in-progress` |
| 1 | your PR is red or change-requested | fix CI or address review with `mergekit fix <N>` |
| 2 | your PR that nobody is reviewing (highest priority, then `unblocks`, then most-recently-updated) | set it up to self-review with `mergekit start <N>`, or request a reviewer |
| 3 † | in-progress issue whose branch you're on *(uncommitted work folds in here as "continue")* | resume, or run `implementkit` |
| 4 | orphaned work: uncommitted on the base branch or an untracked branch, or unpushed commits | run `commitkit`, or push |
| 5 | a stash | restore it with `gitkit rescue` to finish the work, or drop it if obsolete |
| 6 | an unmerged local feature branch | finish it, or clean it and its worktree up with `gitkit clean` |
| 7 † | stale-tracker signal fired | reconcile with `issuekit sync` |
| 8 † | a `ready` issue, or a startable `stacked` one, to start (highest priority, then `unblocks`, then most-recently-updated) | `issuekit start <N>` (worktree via `gitkit`), then `implementkit` |
| 8b | **no tracker:** the next unbuilt phase of the newest plan | build it with `implementkit` |
| 8c † | a `needs-planning` issue (highest priority, then most-recently-updated) | grill it with `grillkit`, then promote it with `issuekit triage` |
| 9 † | an unlabeled issue, or one whose status is outside the lifecycle map, needing classification | classify it with `issuekit triage` |
| 10 † | an unassessed backlog, meaning open issues with no priority label | rank them with `issuekit triage` |
| 11 | an unfiled plan *(only when the tracker is in use)*, or no plans at all | `issuekit create`, or `plankit` |

**† marks a rung that fires only when a tracker is in use.** Resolve that per [Resolving the tracker](#resolving-the-tracker) before ranking, because seven of these rungs turn on it. A project that tracks its work elsewhere falls straight past every one of them, which is exactly the hole rung 8b fills: without it the ladder runs out and crowns nothing, and "no next move" on a repo with unbuilt plans on disk is a survey failure rather than a finding. The PR and git rungs (1, 2, 4, 5, 6) never depend on it, since a branch and a pull request are the same facts whatever the tracker is.

**Rung 8b is rung 8's trackerless twin, and it sits at the same height on purpose.** Both are start-something rungs, both mean the finishing rungs above came up empty, and both hand off the same way once the work is picked. It ranks by the plan's own order, meaning the lowest-numbered unbuilt phase of the newest plan, because a plan's phases are written in dependency order and skipping ahead is how a phase gets built on a prerequisite that does not exist yet.

**A `stacked` issue is startable when its prerequisites' PRs are still open and form one chain**, which the open-PR read already shows, so the check costs no call. One whose prerequisite PR merged or closed is tracker drift: list it on the Issues line and route it to `issuekit sync`, not to `start`, which would refuse it. **Rung 8c sits below every startable issue** because a `needs-planning` issue cannot be started by anyone until a human settles its decisions, and above classification because it is already classified. The move is a human grill session, so it is crowned only when nothing above it fires.

**Rung 0 is numbered zero because it isn't really a rung.** It's the [one documented override](#critical-is-the-one-thing-that-outranks-finish-first) of the finish-first spine, and numbering it inside the sequence would make it look like an ordinary state that merely happens to sort first. It fires rarely, it must name what it displaced, and everything below it is the actual ladder. If rung 0 is firing on most runs, `critical` has stopped meaning anything and the real move is `issuekit triage`.

**Rung 10 ranks below every actionable rung and above "go plan something."** An unranked backlog is a genuine gap, since nothing above it can order itself properly, but it is still tracker hygiene rather than work, so it never outranks a thing the user could actually finish. It earns a rung at all because without one, a repo where nobody has set a single priority would silently rank on leverage forever and never be told why.

**Rung 11's first half only exists when the unfiled set was computed**, meaning [the resolution](#resolving-the-tracker) came back *tracker in use*. A repo that tracks work elsewhere gives statuskit no way to tell a filed plan from an unfiled one, so it never asserts one is unfiled: the rung reduces to its second half, *no plans at all → `plankit`*. Ranking "file your plans" at a project that files its work somewhere else is worse than staying quiet, because it's a confident recommendation built on a read that never happened.

**Rungs 1 and 2 are the same thought twice: your own PR is stuck on you.** A red PR is stuck loudly and an unreviewed one silently, and the silent kind is the one that sits for weeks, which is why it outranks resuming a half-built issue rather than trailing it: the code is already written and green, so it retires the most work for the least effort, which is the whole of finish-first. It's the one rung that breaks ties on leverage while asking you to *finish* rather than start, because there's no context to switch back into: reviewing a finished PR is the same work whichever one you pick, so the tiebreak may as well go to the one that frees the most.

When the owning kit isn't installed, name the **plain action** instead ("commit your changes" rather than "run commitkit"), because statuskit routes and doesn't require the ecosystem.

### 4. Output: the dashboard, then one crowned move

Print the dashboard in the shape below, under the [render rules](#render-rules), then the ranked next-actions list with the **#1 move bolded** and its exact kit/command. Tables carry the detail a bare count can't: with a tracker in use they are the unblocked issues, the PRs waiting for review, and the blocked issues with their blocker; without one the two issue tables have nothing to list and the unbuilt phases take their place. Keep it to one screen:

```
# Project status · <repo> · <branch> · YYYY-MM-DD

## Working tree  <clean | N uncommitted · M unpushed · stash K>

## Issues        in-progress N · ready N · in-review N · blocked N     (omit without gh, or without a tracker)

Unblocked (N) · highest priority first
| Issue | Priority | Unblocks | Status | Last active | Title |
|---|---|---|---|---|---|
| #12 | critical | 3 | ready | 2d | <title> |
| #31 | high | 1 | in-progress | 4h | <title> |
| #47 | none | 0 | unlabeled | 3w | <title> |

## Pull requests <open N: X awaiting review, Y CI-red, Z ready to merge>   (omit without gh)

Waiting for review (X) · highest priority first
| PR | Closes | Priority | Unblocks | CI | Author | Next move | Last active | Title |
|---|---|---|---|---|---|---|---|---|
| #34 | #12 | critical | 3 | ✓ | you | nobody reviewing → yours | 1d | <title> |
| #29 | #19, #23 | high | 0 | ✗ | @someone | yours | 6h | <title> |
| #38 | none | none | 0 | ✓ | you | theirs: @reviewer | 2w | <title> |

Blocked issues (N)
| Issue | Priority | Waiting on | Title |
|---|---|---|---|
| #19 | high | #12 | <title> |
| #23 | low | `blocked` label, no blocker named | <title> |

## Plans         <M unfiled: plan-debugkit, plan-testkit>   (omit entirely unless there is a finding)

Unbuilt phases (N) · plan order      (only when there is no tracker, and a plan carries stamps)
| Plan | Phase | Title |
|---|---|---|
| plan-sso-login | 3 | <phase title> |
| plan-sso-login | 4 | <phase title> |

## Next move
**→ <the #1 action>.** Run `<kit / command>`.

Then:
- <runner-up> · `<kit / command>`
- <runner-up> · `<kit / command>`
- <runner-up> · `<kit / command>`
```

**Every move line is written in the procedural register.** The crowned move, the runner-ups, and the snapshot's checkbox list are read at a glance by someone deciding what to touch next, so use ASD-STE100 Simplified Technical English: one instruction per line, active voice, present tense, name the actor, no metaphor and no word carrying a second meaning. Say "merge #34" and "file the backlog", not "get #34 over the line". Keep one term per thing across the whole dashboard, because a move that calls it the *plan doc* and a panel that calls it the *unfiled plan* read as two different objects. This applies to the printed dashboard and the snapshot file alike, and it is what lets the block be scanned rather than read.

#### Render rules

Every rule for what prints, where, and in what order lives in this table. The snapshot file follows the same rules.

| Element | Rule | Why |
|---|---|---|
| Signal panel | Working tree, Issues, Pull requests, and Plans each put the heading and counts on one line, followed only by a table. A reason for a move goes in the move line. | Four lines tell where the project stands before reading starts. A panel with a second sentence becomes a report. |
| Panel presence | Working tree, Issues, and Pull requests always print, zero counts included. A panel is omitted only when its source is unavailable: Issues and Pull requests without `gh`, Issues when the tracker reading is not present. Say the reason once. | A clean tree and an empty PR list are facts worth confirming, and a fixed panel set keeps two days' snapshots comparable. |
| Plans panel | Prints only with a finding: an unfiled plan when the tracker reading is present, an unbuilt phase of a stamped plan when there is no tracker. Both can print together. No finding means no Plans line, no `## Plans` section in the file, and no mention of why. | An empty plan count (`21 filed · 0 unfiled`) is unactionable, where every other panel reports state that always exists. Plans is the only conditional panel. |
| Extra panel | At most one, for a first-class queue the standard set cannot see (an `IDEAS.md` backlog, an RFC index), filled from a file the survey read. Never a panel filled by running a build, test, or lint. | statuskit surveys read-only, and a closed panel set is what makes two days' files compare. |
| Table order | Unblocked, then Waiting for review, then `Blocked issues (N)`, at most three at once. Blocked issues sit under the Pull requests panel and keep the full name. `Unbuilt phases` sits under Plans. The panel order never changes. | A reader stops at the first row they can act on, so every actionable row comes before the first one they cannot. Away from its panel, a bare `Blocked (N)` reads as blocked PRs. |
| `in-review` issue | One row, in Waiting for review, never in Unblocked. Its count stays on the Issues line. One with no open PR is a note on the Issues line (`in-review 7 · 1 with no open PR`), routed to `issuekit triage`. | The PR row names a person and a CI state. Moving the issue back to Unblocked would claim it is startable. |
| Rows | List every qualifying row. Over 10, cap at 10 and close with `+N more` and the `gh` command that shows the rest. | Completeness is the point, and a silent cut reads as a full list. |
| Empty table | Drop the table and keep its count line (`Waiting for review (0)`). | Zero is a surveyed fact, not a missing panel. |
| Sort | Unblocked and Waiting for review sort by `Priority`, then `Unblocks`, then recency, and the count line declares it (`· highest priority first`, or `· highest leverage first` when Priority drops). `Blocked issues` sorts by recency and carries `Priority` but no `Unblocks`. `Last active` is a column (`4h`, `2d`, `3w`), not the sort. | The row to pick up next belongs on the first line, and a declared sort can be checked against the columns. A blocked row cannot be picked up, so its leverage has nowhere to go, but its priority says whether the blocker is worth chasing. |
| Column order | The sort keys follow the ID on the issue table and follow `Closes` on the PR table. Context columns follow in decreasing order of use. | `PR \| Closes` is the pair that makes a PR row legible. |
| `Closes` cell | Print `none` when the PR closes nothing, never a blank. A stack layer's scraped link prints as `#12 (stacked)`. | `none` warns that the merge will leave its issue open; a blank reads as "not checked". |
| `Next move` cell | `yours`, `theirs: @name`, or `nobody reviewing → yours`. | Naming the reviewer makes the claim checkable. |
| Drop rules | Drop `Author` when every row shares one author (say `all yours` on the count line), `Unblocks` when every value is 0, `Priority` when no row carries one. If a table still does not fit, cut `Title` to its first words. Never drop a sort key. | A column whose values never vary looks like a checked fact. The drops keep the nine-column PR table on one screen. |
| Move lines | One line per runner-up, naming exactly one issue or PR, the same split as the snapshot checkboxes. | The printed list and the file agree item for item. |

### 5. Write the status snapshot, the default rather than an offer

**Write the file every run.** A terminal dashboard scrolls away and its ranked moves can't be ticked off; the same content on disk reads better and doubles as the run's to-do list. So don't ask permission: write it, then say where it went in one line:

> Saved to `docs/status/NNNN-status-<repo-slug>-YYYY-MM-DD.md` · scratch file, gitignored, not committed.

Say `untracked` in place of `gitignored` when the [write rules](#write-rules) skipped the `.gitignore` line.

**Skip only when asked.** "Just print it", "no file", "don't write anything", "screen only", "/statuskit --no-file" all mean honor that for the run and print the dashboard alone. A skip applies to that run only; it isn't a standing preference unless the user says so or the repo's agent-guide file (`CLAUDE.md` or an equivalent) does. Skip silently too when there's no writable filesystem (below).

**Where it goes.** `docs/status/NNNN-status-<repo-slug>-YYYY-MM-DD.md`, using the next serial, a short lowercase kebab-case slug (normally the repo name; use a narrower one such as the branch or issue when the snapshot covers a slice of the project), and the ISO creation date. To get the serial `NNNN`, list `docs/status/`, take the highest leading four-digit serial, and add one; start at `0001` when there is none. The serial is per directory and never reused. Create `docs/status/` if it doesn't exist.

**One file per day, always update, never add.** Before writing, list `docs/status/` and look for a snapshot already carrying **today's date**. If one exists, that's the file: update it in place, keeping its existing name even if this run would have picked a different slug. Only when the directory has nothing dated today do you create a new file. A status file is a point-in-time read, and three of them from one afternoon is how a scratch directory becomes archaeology, and worse, it splits the user's ticked boxes across files that all look current. If today's snapshot genuinely covers a different project in a monorepo, make the slug specific to that project and match on slug + date instead; there is no case where the same project gets two files on the same day, so never fall back to a sequence suffix.

**Updating means merging, not overwriting.** Re-derive the whole survey from git and GitHub, never trusting what the file says, then carry over the **checked state** of every move that's still open, matching on its key (below) and nothing else. Rewrite every other word from the fresh survey: a move whose wording changed completely is the same move if its key matches, and a move that kept its wording by coincidence is a different one if its key doesn't. A ticked move that no longer applies goes to `Done today`; an unticked one that no longer applies just drops.

**What it contains.** The dashboard as printed, with two additions the file earns:

- a **provenance line** recording when the snapshot was taken, against which commit, and how many times it's been rewritten today (`Snapshot: 2026-07-23 14:20 · <branch> @ <short-sha> · run 3 today (first 09:05)`), because without it a stale file reads as current, and without the run count an afternoon rewrite is indistinguishable from the morning's original;
- the ranked moves as a **checkbox list** so the file works as a to-do, crowned move first and each carrying its kit/command:

```markdown
## Next moves

- [ ] **<the #1 move> (critical, unblocks 3)** · `<kit / command>` <!-- k: issue-12 -->
- [ ] <runner-up> (high, unblocks 1) · `<kit / command>` <!-- k: pr-34 -->
- [ ] <runner-up> · `<kit / command>` <!-- k: plan-debugkit -->

## Done today

- [x] <move, as it read when it was ticked> <!-- k: issue-9 -->

## Surfaced, not queued

- #34 approved + CI-green · merge when you're ready (`mergekit close 34`)
- #29 awaiting @someone's review
```

**Every move carries a key.** The trailing `<!-- k: … -->` comment is what the merge matches on, and it exists because the visible text can't be matched on: the wording is regenerated every run, so a move that survives the survey comes back phrased differently and its tick is silently lost. Moves with an issue or PR number are the easy half; the ones without, such as provision the labels or file the backlog, are exactly where text matching fails and where a user's tick most needs to survive. The key is invisible when rendered because the file is read by a human and the key means nothing outside it.

Draw keys from a fixed vocabulary, never an improvised slug, or the key drifts run to run the same way the prose does:

| Move's subject | Key |
|---|---|
| an issue | `issue-12` |
| a PR | `pr-34` |
| a plan doc | `plan-<slug>`, the plan's own slug |
| one phase of a plan | `plan-<slug>-phase-<n>` |
| a local branch | `branch-issue-12-retry-budget` |
| a stash entry | `stash-<sha>`, the stash commit's short SHA from `git stash list --format='%h'`; an index such as `stash@{0}` moves whenever a new stash is pushed |
| a ladder rung with no subject | one fixed slug per rung: `push`, `reconcile`, `triage`, `prioritize`, `repo-labels`, `declare-tracker` |

**A move that frees work says so, and a move somebody ranked says that first.** When a queued move carries a priority above `medium` or an `unblocks` count above zero, put both into its line: `**Start #12 (critical, unblocks 3)** · \`issuekit start 12\``. The checkbox list is where the user actually chooses, often hours after the tables scrolled past, and those two clauses are the whole argument for why this item outranks the one below it. Omit each clause when it says nothing: no `unblocks 0`, and no `medium` or blank, since the default and the absence are both what the reader already assumes. Priority leads the pair when both are present, matching the sort.

The key never leaves the file. Don't put it in a commit message, a branch name, an issue body, or anywhere else: it's a join key between two versions of one gitignored scratch file, and exporting it into permanent history would make durable artifacts reference a throwaway one. The linkage that *does* belong in git already exists, namely `Closes #12` on the PR, which the survey reads anyway.

**Every move must have a signal that retires it.** A queued move is something the next survey can observe as finished: the PR merged, the issue closed, the labels now exist, the tree went clean. Completion is detected that way, not from the ticks; the tick is only a human's own mid-day annotation, which is why the merge has to preserve it and why it is never evidence. A move with no observable signal ("decide whether this repo dogfoods its own workflow") can never drop off on its own, so it re-ranks every run forever and the only thing that ever silences it is a tick that today's file takes to the grave. Those aren't next actions, they're decisions, so route them to `plankit` or file them with `issuekit create`, and let the resulting issue be what appears here. If you can't name what would make a move disappear, it doesn't belong on the list.

**Ticked moves go to `Done today`, not the bin.** When the fresh survey no longer supports a move the user had ticked, that's the move getting *finished*, so record it under `## Done today` rather than deleting it with the rest of the stale ladder. One file per day only pays off if the day accumulates in it; a file that shows nothing but what's left reads identically at 6pm and 9am, which is the one impression a status file must never give. Drop the section entirely on a day with nothing done.

**One task per checkbox, never bundle.** Every item is a single thing the user can finish and tick off on its own, so it names **exactly one** issue or PR. "Start #12, #19, and #23 with `issuekit start`" is three items, not one; so is "triage the 4 unlabeled issues." When a rung of the ladder applies to several issues at once, split it into one item per issue, each carrying that issue's own number, title, and command, and keep them in the rung's order. The whole reason the snapshot is a checkbox list is that a half-done item is invisible: a box covering three issues can't be ticked until all three are done, and until then it reads exactly like nothing has happened. The same rule governs the `Surfaced, not queued` list: one line per PR, never a summary line. If the split makes the list long, that's the true length of the work; cap it the way the tables do, most-recently-updated first, then a `+N more` line, rather than by merging items back together.

All three tables (unblocked, waiting for review, blocked issues) go into the file as printed, in that order. They're the part of the snapshot that ages into a worklist, and a file that kept only the counts would be strictly worse than the terminal it replaced. Beyond the file's own additions, don't inflate it into a report the dashboard didn't contain: same survey, same closed panel set, durable form.

**It's disposable.** This file is scratch, not a tracked artifact, so leave it uncommitted. Commit it only if the user explicitly asks, and then it's their call, so honor it without arguing.

#### Write rules

statuskit writes local files only, and this table is the complete list. Nothing here reaches a remote, a branch, or a tracker.

| Write | When | Gate |
|---|---|---|
| The snapshot, `docs/status/NNNN-status-<slug>-YYYY-MM-DD.md` (a `Write`) | Every run, unless the user asked to skip it or no filesystem is writable. Creates `docs/status/` when missing. | None. Say where it went in the saved line. |
| One `docs/status/` line appended to the root `.gitignore` (an `Edit`) | Before the first snapshot, only when a root `.gitignore` exists and `git check-ignore -q docs/status/x.md` fails. With no root `.gitignore`, create none: the snapshot stays untracked. | None. Say it in the saved line. |
| One declaration sentence appended to an existing agent-guide file (an `Edit`) | Only from [the declaration offer](declaration.md), on an empty-array unknown reading. | A preview and the user's OK. |

**No filesystem?** Print the snapshot as a codeblock with the canonical `docs/status/NNNN-status-<repo-slug>-YYYY-MM-DD.md` path, with `0001` when you can't list their snapshots, so the user can save it themselves.

## Notes

- **Nothing outward-facing ever changes.** statuskit surveys and advises; it never touches git or GitHub state. If a recommendation needs that kind of mutation, it routes to the kit that owns it, and that kit previews and gets approval on its own. The [write rules](#write-rules) list every file statuskit writes: the snapshot every run, one `.gitignore` line before the first snapshot, and a declaration sentence only on approval. None reaches a remote, a branch, or a tracker, which is the property that makes statuskit safe to run at any time. State the boundary that way rather than as "zero mutation", because the snapshot was always a write and a headline the skill contradicts is worse than a narrower one it keeps.
- **Route, don't launch.** Routing means *naming* the kit and its one-line command, because statuskit never invokes the kit for you; the user launches it. Naming "run `issuekit sync`" and then calling the kit yourself would restart mutation in the same breath as "orient me," breaking the read-only stance.
- **Route, don't require.** Every recommendation degrades to a plain command when its kit isn't installed. statuskit is useful in a bare repo with only git.
- **Hold the issuekit line.** Display issue counts, the unblocked set by ID, the blocked set with what each says it's waiting on, the ready/in-progress set, and each issue's declared priority; compute the one staleness boolean to rank "reconcile." Listing IDs is not crossing the line, because it's the same read printed usefully, and it saves a round trip to `gh` before acting on the crowned move. What stays on issuekit's side is *judgment* about the tracker: never render an itemized health verdict, and the moment you're explaining which issues are stale and why, that's issuekit `triage`/`sync` and statuskit should be pointing at it, not doing it.
- **statuskit reads priority; it never assigns one.** Printing the label an issue carries is a fact read like any other, and sorting on it is what the label is *for*. Inferring a priority for an unranked issue is not, because it's the tracker judgment that belongs to issuekit `triage`, and it's the one place this survey could quietly manufacture the very signal it claims to be reporting. An unassessed issue stays unassessed in the dashboard, sorts below `low`, and gets routed rather than guessed at.
- **gitkit owns the git facts.** The base branch, the branch-name convention, and where a worktree lives all come from gitkit, and statuskit reads them and reports. Keeping a second copy of any of them here is how a dashboard starts confidently describing a repo that no longer matches it.
- **`Edit` is here for two appends, and for nothing else**: the `docs/status/` line in `.gitignore` and the declaration sentence in an agent-guide file. The snapshot is a `Write`. Strip the tool on a host that enforces the field and both degrade on their own: the snapshot stays untracked, and [the declaration offer](declaration.md) prints the line for the user to place.
- **`Skill` is in the tool list for gitkit, and for nothing else.** It looks removable next to the route-don't-launch rule above, so it is worth stating: statuskit *calls* gitkit during the survey for the base ref, the branch-name pattern, and worktree paths. Every other kit it names in a move line is routed to, never invoked. Strip the tool and the survey silently starts guessing that the base branch is `main`.
- **On-demand, no state.** Every run is a fresh read: statuskit keeps no `STATUS.md` at the repo root and no last-run cache, and it never *reads* a snapshot back to shortcut the survey. The one thing it takes from an existing file is which boxes were already ticked; the survey itself is always re-derived from git and GitHub. A `docs/status/` file is output for a human (or the next agent), not memory statuskit trusts.
