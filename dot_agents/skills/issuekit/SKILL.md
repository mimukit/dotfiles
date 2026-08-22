---
name: issuekit
description: >-
  Own the GitHub issue lifecycle with five modes: create issues from a plan or description (kept independent for parallel worktree work), start a `ready` issue into its own worktree, close one out once its PR merges, sync PR↔issue links after merge, and triage the tracker for lifecycle and priority gaps. Use when the user says "create issues from this plan", "file an issue", "start issue #42", "close #42", "wrap up #42 now the PR merged", "sync my issues", "triage the backlog", "prioritize my issues", "set the priority on #42", "issuekit", or wants issues opened, started, landed, reconciled, ranked, or reviewed with the gh CLI.
license: MIT
allowed-tools: Bash, Read, Edit, Write, Skill
metadata:
  internal: false
---

# issuekit

Own the GitHub issue lifecycle through the [`gh` CLI](https://cli.github.com), in five explicit **modes**:

- **`create`.** Turn a plan document or a plain description into well-formed issues, with parent→child links.
- **`start`.** Take a `ready` issue into its own worktree and flip it `in-progress`.
- **`close`.** Once its PR has merged, close the issue, unblock what it was holding up, and tear the worktree down.
- **`sync`.** Reconcile and repair the PR↔issue relationship *after* the fact (issues a merged PR should have closed, a missing link on an existing PR, an un-ticked parent checklist).
- **`triage`.** Report the health of the tracker, then offer fixes you approve.

One skill, five jobs, because they're the same job at five points in a dev workflow: file the work, pick it up, land it, keep everything in sync as PRs merge, and keep the tracker honest.

**`close` vs `sync`.** They do overlapping tracker work and the split is by *scope*, not mechanism: `close` lands **one named issue** whose PR you know merged, and is the only mode that touches the filesystem (the worktree teardown). `sync` sweeps the **whole tracker** for drift after the fact, meaning issues a merged PR should have closed but didn't, missing links, and un-ticked parents, and it never touches a worktree. `close` reuses `sync`'s reconciliation rather than restating it.

## When this fires

The user wants to act on GitHub issues. Route to a mode from what they ask:

- **create.** "Create issues from this plan", "open issues for `plan-auth.md`", "file an issue for X", "file this as an issue".
- **start.** "Start issue #42", "begin #42", "pick up #42", "spin up a worktree for #42", "I'm working on 42 now".
- **close.** "Close #42", "close out #42", "wrap up #42 now the PR merged", "tear down #42's worktree", "#42 landed, clean it up".
- **sync.** "Sync my issues", "this PR merged but the issue is still open", "link this PR to #42", "tick the parent checklist".
- **triage.** "Triage the backlog", "what's the state of my issues", "review open issues", "any stale issues", "prioritize my backlog", "set the priority on #42", "nothing has a priority".

**If no mode is clear, ask first.** Present the modes as options and let the user pick before doing anything, and don't guess between creating and mutating the tracker.

**Worktrees and branches are gitkit's.** `start` and `close` bookend a worktree's life, and both get it from **gitkit**, where the branch name, the path convention, create-or-adopt, and teardown all live. issuekit answers *"is this issue workable, and what does the tracker say now?"*; gitkit answers *"where does the code for this branch live?"* Neither reaches into the other's internals: issuekit hands gitkit an issue number and title, gitkit hands back a branch and a path.

## Preflight (every mode)

Before any GitHub call, confirm the tooling is ready:

```sh
gh --version        # gh installed?
gh auth status      # authenticated?
gh repo view --json nameWithOwner -q .nameWithOwner   # inside a repo?
```

- If `gh` is missing or unauthenticated, say so and point to `https://cli.github.com` / `gh auth login`. Don't work around it.
- **Invoking issuekit answers the question of whether this project uses GitHub Issues.** Not every project tracks work here, and a skill that surveys a repo has to resolve that before it recommends anything. issuekit never does: someone asking to file, start, or close an issue has already said where the work lives. So `create` files issues without first checking whether the project files issues, and no mode ever declines on the grounds that the repo looks like it tracks work elsewhere.
- **No shell or `gh` at all** (e.g. a browser-based agent)? You can't call `gh`. Instead do the reasoning from what the user provides and **print the exact `gh` commands** for them to run themselves: issue bodies as codeblocks, and `gh issue create …` / `gh issue close …` lines ready to paste.

**Safety stance, for the whole skill.** Creating, closing, relabeling issues and editing PR bodies are outward-facing mutations. **Preview every mutation and get an OK before it runs, so nothing changes on GitHub unprompted.** Never merge PRs.

**One exemption, and it belongs to the mode, not the caller.** [`start`'s `ready → in-progress` flip](#4-flip-the-label-ready--in-progress) runs without a preview, for every caller, meaning a person at the keyboard and an unattended orchestrator alike. It's the only mutation here that asks a question already answered twice over: [the `ready` guard](#1-guard-refuse-anything-not-ready) has refused everything a human hasn't grilled, and invoking `start <n>` *is* the instruction to start the issue. Flipping the label is what "started" means in the tracker, so a confirmation prompt buys nothing and costs the one thing `start` exists to protect: an issue sitting in a worktree while the tracker still advertises it as free for someone else to pick up. Nothing else widens: `create` still previews, `close` still previews, `sync` and `triage` still preview every move, and no caller of any kind gets to skip the guard itself.

## Title convention (every issue this skill creates)

Issue titles follow the same shape as commitkit's commit subjects and the [Conventional Commits specification](https://www.conventionalcommits.org), so the tracker and the git log read as one workflow. **Format:**

```
type(scope): short imperative summary
```

Pick the `type` from what the issue delivers, not the files it touches. The set mirrors commitkit's, with one addition (`epic`) for parent issues:

| type | when |
|------|------|
| `epic` | a **parent** issue that groups child issues/sub-issues |
| `feat` | a new capability the user can see |
| `fix` | a bug fix |
| `docs` | documentation only |
| `refactor` | behavior-preserving code change |
| `perf` | a performance improvement |
| `test` | adding or fixing tests |
| `build` / `ci` | build system, deps, or pipeline |
| `style` | formatting/whitespace, no logic |
| `chore` | routine maintenance that fits nothing above |

Rules, applied to **every** title you generate:

- **`(scope)` is mandatory**, naming the module, package, directory, or feature area the work belongs to (`feat(auth): …`). For genuinely global work (repo-wide config, tooling, cross-cutting cleanup) fall back to `repo`: `chore(repo): …`.
- **Entirely lowercase.** Never capitalize any word in the title, including the first. Proper nouns and acronyms (`OIDC`, `SSO`, `CI`) are the only exceptions.
- **Imperative mood**, stating the *effect* ("add sso login"), not the activity ("changes to auth"). **No trailing period.** Keep it concise.
- A parent epic and its children **share the scope** so the group is obvious in the list: `epic(auth): …` over `feat(auth): oidc login end to end`, `feat(auth): sso account linking`.

If the repo has its own issue-title style (visible in `gh issue list` or an `.github/ISSUE_TEMPLATE/`), follow that instead and say you did; see [Notes](#notes).

---

## Lifecycle labels (every mode)

issuekit tracks where an issue sits in the workflow with a small, **flat** set of status labels. It **uses** these labels and never creates them. Provisioning labels is the job of a companion skill, **repokit**. When a label this skill needs is absent from the repo, **stop and tell the user how to add it** (run `repokit`, or the exact `gh label create` line) rather than creating it yourself or skipping silently.

The canonical map has exactly one **status** label active at a time, moving left to right through the workflow, with the three side-exits applying whenever they fit. This table is the **shared contract with repokit**, the skill that provisions these labels. Maintainers must keep the two tables aligned on names, colors, and meanings:

| label | color | means | typically set by |
|-------|-------|-------|------------------|
| `triage` | `FBCA04` | filed, not yet assessed or broken down | create (ad-hoc), triage |
| `needs-planning` | `F1C40F` | not yet specified enough to work; a human plan/grill session is still owed | issuekit create / afkkit gate |
| `ready` | `0E8A16` | specified and **independent**, safe to take into its own git worktree now | issuekit create |
| `blocked` | `D93F0B` | has an unmet prerequisite; the blocker is named in the body as `Blocked by #N` | issuekit create / sync |
| `in-progress` | `1D76DB` | actively being worked in a worktree | issuekit start |
| `in-review` | `5319E7` | a PR is open, awaiting review or merge | a PR-authoring skill / sync |
| `needs-info` | `D4C5F9` | stalled pending more detail before it can proceed | triage |
| `wontfix` | `FFFFFF` | will not be actioned | triage |
| `duplicate` | `CFD3D7` | superseded by another issue | triage |

A **closed** issue needs no `done` label, because the closed state is the signal.

**`ready` vs `blocked` is the parallel-work pair.** issuekit sizes and sequences issues so each can be picked up in its own worktree with no ordering constraint, and those get `ready`. The exception, an issue that genuinely can't start until another lands, gets `blocked` plus a `Blocked by #N` line in its body: the label says *that* it's blocked, the body says *by what*. `gh issue list --label ready` is then the exact set the user can fan out in parallel right now.

**`needs-planning` vs `ready` is the human-gate pair.** `ready` means specified enough to work **unattended**, so an agent (or an orchestrator like afkkit) can take it straight to a PR without a human. `needs-planning` means a human plan/grill session is still owed before the issue is workable at all. An issue earns `ready` only once its decisions are settled by a grill; see [the grill gate at creation](#5-label-lifecycle-state-and-priority-and-record-dependencies). `gh issue list --label needs-planning` is then the exact set that still needs the human, the mirror of the `ready` fan-out set.

**Type lives in the title, not a label.** Issues already carry `feat(scope):` / `fix(scope):` per the [title convention](#title-convention-every-issue-this-skill-creates), so this map has no `type:` labels, only lifecycle status.

**When a needed label is missing**, check once with `gh label list`, then report the gap instead of mutating around it:

> Label `blocked` isn't in this repo. Provision the workflow labels with **repokit**, or add just this one:
> `gh label create blocked --color D93F0B --description "has an unmet prerequisite (see 'Blocked by #N' in the body)"`

Apply a label only once it exists (`gh issue edit <n> --add-label <label>`) and, like every mutation in this skill, [preview it and get an OK first](#preflight-every-mode).

---

## Priority labels (every mode)

The **second** label namespace, and the one that decides what gets picked up next. Like the lifecycle set, issuekit **uses** these labels and never creates them: **repokit** provisions them, and a missing one is [reported, not worked around](#lifecycle-labels-every-mode).

| label | color | means | typically set by |
|-------|-------|-------|------------------|
| `critical` | `B60205` | drop everything; preempts work already in progress | issuekit create / triage |
| `high` | `E99695` | do this before other workable issues | issuekit create / triage |
| `medium` | `FEF2C0` | normal priority, the default once assessed | issuekit create / triage |
| `low` | `C5DEF5` | worth doing eventually; never preempts anything | issuekit create / triage |

This table is the other half of the **shared contract with repokit**; keep names, colors, and meanings aligned across both skills.

**Lifecycle and priority are orthogonal, so one label from each, and neither implies the other.** Lifecycle answers *can this be worked?*; priority answers *should this be worked next?* An issue is `ready` **and** `high`, or `blocked` **and** `critical`, and both are coherent: a `low` issue that's workable right now is still workable, and a `critical` one that's blocked is exactly why its blocker matters. Never infer one from the other, because promoting an issue to `ready` because it's `critical` is how ungrilled work reaches an unattended worker, and the `ready` guard exists precisely to stop that.

**No priority label means unassessed, not `medium`.** The absence is a real state, and it's the one `triage` hunts for. Don't silently default an issue to the middle: an unranked issue that everyone assumes is normal-priority is indistinguishable from one somebody actually thought about, and the whole value of the scale is that distinction. Priority is expected on every open issue except the side-exits (`wontfix`, `duplicate`), which are going nowhere and need no rank.

**Exactly one priority label at a time, and you have to enforce it, because GitHub won't.** Labels are a flat namespace with no mutual exclusion, so nothing stops an issue carrying `critical` and `low` at once, and an issue with two priorities sorts unpredictably everywhere downstream. Every write is therefore a *replace*, not an add: read the issue's current labels, and remove whichever sibling is actually there in the same call that adds the new one.

```sh
gh issue view 42 --json labels -q '[.labels[].name]'   # → ["ready","medium"]
gh issue edit 42 --add-label high --remove-label medium
```

Compute the removal from what the issue actually carries rather than blind-removing all three siblings, because it keeps the preview honest (`medium → high` reads differently from `set high`) and doesn't depend on how your `gh` version handles removing a label that was never there.

---

## Mode: `create`

Turn work into issues. Two inputs: a plan file (the main path) or a plain description (start fresh).

### 1. Find the input
- **Plan path:** a `plan-<slug>-YYYY-MM-DD.md`. Resolve it by precedence: an explicit path in the prompt → the newest canonical plan under `docs/plans/` (creation date is the filename suffix) → ask which plan.
- **Ad-hoc path:** a plain description with no plan. This is the "start fresh, just file it" case → one well-formed issue.

### 2. Decompose a plan into a proposed breakdown
Read the plan's structure (phases, milestones, tasks) and decide the shape:
- a **parent epic + N child issues** when the plan has distinct sub-tasks worth tracking separately, or
- a **flat list** (or single issue) when it doesn't.

Four principles govern the breakdown, applied **before** you present anything:

- **Fewest issues by default.** Actively look for scopes where several related tasks can collapse into **one issue with a checklist** instead of separate issues. Merge aggressively; only split into its own issue/sub-issue when a task is genuinely independent, meaning a different lifecycle, owner, or PR. Default to the *smallest* number of issues and sub-issues that still tracks the work honestly. The user can always ask to split one further; starting consolidated and splitting on request beats starting fragmented.
- **Vertical slices.** Size each issue/sub-issue so it completes **one testable feature end to end** whenever possible, meaning a slice a person could verify on its own, rather than a horizontal layer (e.g. "all the DB models", "all the endpoints") that isn't demonstrable until other issues land. Prefer "user can log in with SSO" over separate "add OIDC table" / "add OIDC route" / "add OIDC UI" issues; fold those layers into the one vertical slice as checklist items. Size it, too, so one slice **fits in a single fresh agent context / worktree session**: if a slice couldn't plausibly be finished in one sitting, it's a sign to split it.
- **Independent by default.** Size and sequence issues so each can be picked up in its own git worktree and worked **in parallel**, with no issue waiting on another. When two candidate slices share state (a migration one creates and another consumes, an API contract one produces), first try to **design the dependency away**: fold them into one issue, or resequence so the shared piece ships inside the prerequisite. Only when a real ordering constraint survives do you record it: the dependent gets [`blocked`](#lifecycle-labels-every-mode) and a `Blocked by #N` line, everything else gets `ready`. This is what makes the tracker safe to fan out across worktrees.
- **Prefactor first.** Before slicing the feature, look for a simplifying refactor that makes the real change trivial: *"make the change easy, then make the easy change."* File that refactor as its own `ready` issue (behavior-preserving → `refactor(scope):`) that the feature slices then build on. A clean prefactor often *removes* a dependency that would otherwise force a `blocked` chain, so it earns its keep even as an extra issue.

**Wide mechanical refactors.** When a change has broad blast radius and genuinely can't be one vertical slice, such as renaming a shared column or retyping a symbol used everywhere, don't file it as one giant issue. Sequence it **expand → migrate → contract**:

- **expand.** Add the new form alongside the old; nothing breaks yet. `ready`.
- **migrate.** Update call sites in batches by area, each batch its own issue [`blocked`](#lifecycle-labels-every-mode) by the expand issue (`Blocked by #<expand>`). The batches are independent of *each other*, so fan them out in parallel.
- **contract.** Delete the old form once nothing uses it, `blocked` by all the migrate batches.

This turns one un-sliceable change into a fan of mostly-parallel issues with honest `Blocked by #N` edges, and reuses the existing `ready`/`blocked` machinery, with no new labels. If the batches can't each stay green on their own, add one final integrate-and-verify issue blocked by them all.

**Milestones are opt-in.** Do **not** create GitHub milestones by default; map a plan's phases onto issues and checklists instead. Only when the user **explicitly asks** for milestones (or points at a repo that already uses them) should you create one (`gh api --method POST repos/{owner}/{repo}/milestones -f title="<title>"`, then `gh issue create --milestone <title>`) and attach issues to it. Absent that ask, never introduce a milestone the user would then have to maintain.

Present the proposal as a **preview table** and stop for approval. Do **not** create anything yet:

| # | Type | Title | Parent | Priority | Depends on | Checklist |
|---|------|-------|--------|----------|-----------|-----------|
| 1 | epic | `epic(auth): add sso login` | none | high | none | none |
| 2 | child | `feat(auth): oidc login end to end` | #1 | high | none | provider · session · token refresh · UI |
| 3 | child | `feat(auth): sso account linking` | #1 | medium | #2 | link existing · unlink · conflict handling |

Titles follow the [title convention](#title-convention-every-issue-this-skill-creates): `type(scope): summary`, lowercase, the epic and its children sharing the `auth` scope. Each child is a vertical slice with its layers folded into a checklist, not one issue per layer. The **Depends on** column is where independence is decided out loud: an empty cell means the issue is `ready`, so pick it up in its own worktree now, while a `#N` means it's `blocked` by that issue (row 3 waits on row 2). Keep the column as empty as honesty allows; a mostly-empty column is a tracker the user can fan out in parallel. Let the user add, drop, retitle, reparent, **reprioritize**, **resequence to break a dependency**, or **split** any row before you proceed, and offer splitting explicitly when a slice is large. This guard is the point, so never spray a repo with auto-generated issues.

**Propose a [priority](#priority-labels-every-mode) per row, and expect to be overruled.** You can read relative importance off a plan, meaning what it calls out as the core of the feature versus the polish, what it defers, and what it flags as a risk, and that's a real signal worth putting in the column. What you cannot read is why the work is being done at all, which is the thing priority actually encodes. So propose from the plan, mark anything the plan doesn't rank as `medium`, and treat the column as the one most likely to be corrected. This is exactly the right moment for that correction: setting priority here costs the user one glance at a table they're already reviewing, where doing it later means a pass back over issues that have scattered across the tracker.

**Don't hand out `critical` from a plan.** It means *preempt work already in progress*, which is a claim about right now and not about the plan, and a document written last week cannot know what's in flight today. Propose `high` for the most important row and let the user escalate it if they mean it.

For an **ad-hoc** description, skip the table: draft one issue (title + body) and confirm it before creating.

### 3. Create the issues
**Guard against duplicates first.** create is the workflow's entry point and gets re-invoked, so running it twice on one plan must not file a second set. Before creating, list existing issues and skip (or flag for the user) any whose title already matches:

```sh
gh issue list --state all --limit 200 --json number,title,state
```

On trackers with more than 200 issues, raise the limit or use `gh search issues --repo {owner}/{repo} --match title "<candidate title>"` so older duplicates are not silently missed.

Then write each issue with a title in the [`type(scope): summary` convention](#title-convention-every-issue-this-skill-creates) and a body that carries the relevant slice of the plan: context, acceptance criteria, and any decisions. Create parents before children so child bodies can reference them.

Two conventions for the body:

- **Write acceptance criteria as `- [ ]` checkboxes**, giving a concrete, verifiable definition of done for *this* issue. (Distinct from the sub-issue/parent checklist below, which tracks child issues.)
- **Don't hard-code file paths**, because they go stale as the branch evolves; describe the change by behavior and area instead. The one exception is a **decision-rich snippet** (a schema, state machine, type, reducer) where the decision *is* the code, so include it, trimmed to just the substantive part.

```sh
gh issue create --title "epic(auth): add sso login" --body-file <bodyfile>
```

Use a temp file for each body (multi-line markdown through `--body` is flaky) and clean it up after.

### 4. Link parents → children
Try GitHub's **native sub-issues** first, then fall back:

```sh
# Native (preferred): attach a child to its parent via the sub-issues API.
# sub_issue_id is the child's DATABASE id (an integer), NOT the GraphQL node id
# that `gh issue view --json id` returns. Resolve it from the REST endpoint:
child_id=$(gh api repos/{owner}/{repo}/issues/{child_number} --jq .id)
# Attach it, using -F (typed integer), not -f (which would send a string and be rejected):
gh api --method POST repos/{owner}/{repo}/issues/{parent_number}/sub_issues \
  -F sub_issue_id="$child_id"
```

If that call fails, whether because sub-issues are disabled, on older GitHub Enterprise, or through insufficient permissions, **fall back** to a task-list checklist in the parent body and **tell the user which path was used**:

```markdown
### Sub-issues
- [ ] #43 wire OIDC provider
- [ ] #44 session + token refresh
```

### 5. Label lifecycle state and priority, and record dependencies
Apply the [lifecycle labels](#lifecycle-labels-every-mode) so the fresh issues advertise their state. The **grill gate** decides which vocabulary applies, because `ready` is a promise the work can run *unattended*, earned only when the decisions are already settled:

- **Grilled source.** The input plan file carries a `Grilled: YYYY-MM-DD` stamp (grillkit writes it when it hardens a plan), *or* the user explicitly says the work is grilled/ready. The decisions are settled, so the normal pair applies: every independent issue gets `ready`, every dependent one gets `blocked` plus a `Blocked by #N` line in its body naming the prerequisite.
- **Ungrilled source.** An ad-hoc description, or a plan with no grill stamp. The decisions aren't settled, so **every issue gets `needs-planning`**, because it still needs a human plan/grill session before anything unattended should touch it. Record any `Blocked by #N` dependency in the body anyway; it takes effect once the issue is grilled into `ready`. This is what keeps afkkit (and any unattended worker) from picking up work a human hasn't grilled yet.

Then apply the [priority label](#priority-labels-every-mode) the user approved in the preview table, **one per issue, in the same `gh issue edit` call** as the lifecycle label, so a fresh issue never exists in a half-labeled state that a concurrent survey could read.

Priority is applied **regardless of the grill gate**. The gate governs the lifecycle namespace only: an ungrilled issue is `needs-planning` because nobody has settled its decisions, but "this matters more than that" is a judgment the user just made in the preview and it doesn't need a grill session to be true. Dropping it here would mean the ungrilled backlog, the exact pile that most needs ordering, is the one part of the tracker nothing can rank.

Confirm each label exists first (`gh label list`), and if one is missing, stop and point the user at **repokit** or the `gh label create` line rather than creating it yourself. Check both namespaces in that one call; a repo that predates priority will have the lifecycle nine and none of the four.

```sh
# grilled plan → ready / blocked, each with its approved priority
gh issue edit 43 --add-label ready --add-label high
gh issue edit 44 --add-label blocked --add-label medium   # body carries: Blocked by #43
# ungrilled source → needs-planning, still ranked
gh issue edit 45 --add-label needs-planning --add-label low
```

Preview the label set alongside the issues and get an OK before applying, as with any other mutation.

### 6. Write the issue numbers back into the plan
Once issues exist, annotate the source `plan-<slug>-YYYY-MM-DD.md` so it stays the source of truth. Add the ref next to each task it maps to without changing its creation-date suffix:

```markdown
### Phase 2: auth (#41)
- OIDC provider (#43)
- session + token refresh (#44)
```

Use `Edit` for this. For an ad-hoc issue with no plan file, skip this step.

### 7. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Give a table of what you created: number, title, parent, URL, lifecycle label, and priority. Note whether links used native sub-issues or the task-list fallback, and that the plan was annotated.

**Where it landed.** Call out the **`ready` set** (issues the user can start in parallel worktrees right now) versus the **`blocked` set**, naming what each blocked issue waits on. Order the `ready` set by priority, since that set exists to be picked from.

**Next.** Route on which set came back non-empty, naming a sibling kit only when it's installed and otherwise describing the action plainly:

- **`ready` issues exist** → pick one up with `start <n>`, which gets it a worktree and flips it `in-progress`. Crown the **highest-priority** one rather than listing all of them, breaking a tie on whichever frees the most other work.
- **everything is `needs-planning`** (an ungrilled source) → the next move is a human grill session, meaning **grillkit** on the plan, then re-run `create`, or relabel by hand once the decisions are settled. Nothing here is workable unattended yet, so say that plainly rather than offering `start`.
- **everything is `blocked`** → surface the root prerequisite; that's the only thing anyone can act on.

---

## Mode: `start`

Pick an issue up: guard that it's actually workable, get it a worktree, and move it to `in-progress`. This is the moment the tracker and the filesystem meet, and it is deliberately thin: the tracker half is issuekit's, the worktree half is gitkit's, and there is nothing in between.

### 1. Guard: refuse anything not `ready`

**Never start an issue that isn't labeled `ready`.**

```sh
gh issue view <n> --json labels,title,state
```

This one guard carries more weight than its size suggests, and it is the reason `start` lives here rather than in a worktree skill. An issue only reaches `ready` two ways: a human grilled its decisions settled, or issuekit `sync` promoted it `blocked → ready` when its prerequisite landed. So refusing everything else enforces **both the dependency graph and the human-grill gate for free**: no unattended worker can get ahead of the tracker, and none can get ahead of human judgment.

That last part is load-bearing for an orchestrator that calls `start` itself with nobody watching (afkkit does exactly this, as the first step of every run). The gate does not depend on who types the command: it's the `ready` *label* that carries the human's judgment, earned upstream at the grill, and nothing that calls `start` can award it. So refuse on the label alone, and never soften the guard because the caller sounds confident, names a plan, or says it's fine.

Refuse with the reason, not a bare error:

- **`needs-planning`** → the decisions aren't settled; it needs a human grill session first.
- **`blocked`** → name the `Blocked by #N` prerequisite and its state.
- **`in-progress`** → it's already started; go to the adopt path below rather than treating this as a failure.
- **closed, or no lifecycle label** → say which, and offer `triage` to classify it.

### 2. Derive the branch name

**gitkit owns branch naming**, so hand it the issue number and title and use what comes back. For an issue titled in the [`type(scope): summary` convention](#title-convention-every-issue-this-skill-creates), that yields `issue-<n>-<slug>`: the prefix stripped, the summary kebab-cased and capped. Don't re-derive the shape here; a second copy of the slug rules drifts from the one gitkit uses to *find* the worktree later, and then lookup silently stops matching.

### 3. Get the worktree from gitkit, create or adopt

Call gitkit for the branch. It looks the branch up first and **adopts an existing worktree** if there is one, creating a fresh one off the resolved base ref only when there is none. That is what makes `start` safe to re-run: the re-run path is real (an issue escalated back to `needs-planning`, grilled, and picked up again), and it must never recreate, never error, and never disturb work already sitting in the worktree.

issuekit does not choose the path, the base ref, or the git commands. If gitkit isn't installed, say so and stop rather than improvising a worktree convention, because a worktree in the wrong place is worse than none, since everything downstream then looks in the right place and finds nothing.

### 4. Flip the label `ready → in-progress`

```sh
gh issue edit <n> --remove-label ready --add-label in-progress
```

**Run it without asking.** This is [the skill's single exemption from the preview rule](#preflight-every-mode), it applies to every caller, and it applies to this flip and nothing else. Report the flip in the hand-off rather than proposing it first. If the issue was already `in-progress` (the adopt path), leave the label alone and say so. If either label is missing from the repo, [report the gap](#lifecycle-labels-every-mode) and point at **repokit**, because the exemption skips the prompt, never the provisioning check.

### 5. Hand off

**What changed.** Report the label move (`ready → in-progress`, or that it was left alone on the adopt path).

**Where it landed.** Give the branch and the worktree path, and whether it was created fresh or adopted.

**Next.** The ground is prepared and nothing has been built, so the next move is always *switch into that worktree and start there*. Give the `cd` and name the builder: **implementkit** against this issue when it's installed, otherwise plain "implement the issue in that worktree". For an unattended run, **afkkit** takes it from here to an open PR, and since afkkit calls `start` itself, mention it as `afkkit <n>` from anywhere rather than as something to run from inside the worktree; it adopts the worktree this run just prepared.

**Stop there.** `start` prepares the ground and nothing else. It does not implement, does not launch an agent, and does not commit; naming the next step is routing, not doing it.

---

## Mode: `close`

The other bookend to [`start`](#mode-start): the issue's PR has merged, so close it out and reclaim its workspace. Every step here is destructive or outward-facing, so unlike `start` this mode **previews and waits for an OK** before it mutates anything.

### 1. Confirm the PR actually merged, a hard precondition

```sh
gh pr list --search "<n>" --state merged --json number,title,url,closingIssuesReferences
gh pr view <pr> --json state,mergedAt
```

**A merged PR is required, not assumed.** If none is found, whether no PR at all or one that's still open, `close` does **nothing**: no close, no label change, no worktree removal. Report exactly what's blocking (`PR #X still open`, `no PR found for #N`) and stop.

This precondition is the whole reason `close` is safe to run on a name you half-remember. Its two irreversible acts, closing the issue and deleting a worktree, are both gated behind evidence that the work actually landed. A forced teardown of unlanded work stays a deliberate thing the user does themselves, through gitkit directly.

### 2. Preview, then confirm

Show the full consequence in one line and wait:

> PR #10 (`feat(auth): add sso login`) merged → close #42, tick parent #41's checklist, unblock #44, remove the worktree for `issue-42-add-sso-login`.

Name every effect, including the ones that feel routine. Unblocking a dependent changes what someone else picks up next; removing a worktree deletes a directory they may have a terminal sitting in.

### 3. Reconcile the tracker

Close the issue, tick the parent epic's checklist, and flip any dependents `blocked → ready`. **This is [`sync`](#mode-sync)'s job and `close` reuses it rather than restating it**, so apply [Reconcile](#1-reconcile-a-merged-pr-whose-issue-never-closed), [Checklist](#3-checklist-tick-the-parent-when-a-child-closes), and [Labels](#4-labels-advance-lifecycle-state-unblock-whats-freed) to this one issue:

```sh
gh issue close <n> --comment "Closed by #<pr> (merged)."
gh issue edit <n> --remove-label in-review --remove-label in-progress
# tick "- [ ] #<n>" → "- [x] #<n>" in a task-list parent's body
# for each dependent whose body says "Blocked by #<n>":
gh issue edit <dep> --remove-label blocked --add-label ready
```

Closing strips the active status label in the same action, because a closed issue must never carry a stale `in-review`. Native sub-issues tick themselves; only the task-list fallback needs the body edit.

### 4. Tear the worktree down through gitkit, keyed on the branch

Hand this to **gitkit**, which looks the worktree up by its branch (`issue-<n>-<slug>`) through `git worktree list --porcelain`. Lookup is by branch, never by guessing at a path, which is what lets it find a worktree that predates the current path convention, or one that was moved.

gitkit's own teardown rules apply and issuekit does not override them:

- **A dirty worktree stops the removal** and shows what would be lost. A merged PR does not guarantee an empty worktree: scratch files, a stashed experiment, or an un-pushed follow-up commit all live there, and none of them are in the PR.
- **Already gone → "already gone"**, not an error. `close` is idempotent in the same spirit as `start`'s adopt-and-stop; re-running it after a partial run is normal.
- **The branch is deleted only if it's merged**, with `-d` rather than `-D`, so git itself refuses to drop unmerged work.

If no worktree matches the branch, say so and carry on, because the tracker half of `close` still succeeded.

### 5. Hand off

**What changed.** Report the issue closed and by which PR, the parent ticked, and each dependent unblocked (`blocked → ready`).

**Where it landed.** Say whether the worktree was removed, left dirty, or already gone. If it survived, name the path and why, so it doesn't quietly linger.

**Next.** Closing an issue is the moment a slot opens up, so point at what fills it, naming a kit only when it's installed:

- **this close unblocked something** → that dependent is the strongest candidate; name it and offer `start <n>`.
- **nothing was unblocked, but `ready` issues exist** → offer `start` on the most-recently-updated one.
- **nothing is `ready`** → the workable queue is empty, so the move is back up the funnel: **statuskit** to re-orient, or `triage` if the tracker looks like it's hiding work.
- **the worktree survived dirty** → that outranks everything above. Say it first; unlanded work in a stale worktree is what gets lost.

---

## Mode: `sync`

Reconcile and repair the PR↔issue relationship. **Sync deliberately does not write the forward `Closes #N` link onto a fresh PR**, because that belongs to the PR-authoring step (a prkit-style skill) at open time. Sync only earns its place where the automatic chain *broke*:

| Who | Owns |
|-----|------|
| PR-authoring skill | write `Closes #N` into a **new** PR at open time (forward, happy path) |
| **issuekit sync** | reconcile drift after merge, repair a missing link on an **existing** PR, tick parent checklists, advance lifecycle labels and unblock dependents |

### 1. Reconcile a merged PR whose issue never closed
Find PRs merged recently whose linked issue is still open because the `Closes #` keyword was missing:

```sh
gh pr list --state merged --limit 20 --json number,title,body,closingIssuesReferences
gh issue list --state open --json number,title
```

For each merged PR that *should* have closed an issue (evident from the branch, title, plan, or the user telling you), **preview it and confirm before closing**:

> PR #10 (`feat(auth): add sso login`) merged, but issue #42 is still open → close #42 with a comment linking the PR?

On approval:

```sh
gh issue close 42 --comment "Closed by #10 (merged)."
```

Closing is a lifecycle transition too, so strip any active status label (`in-review`, `in-progress`, …) in the same action and a closed issue never carries a stale status (see [Labels: advance lifecycle state](#4-labels-advance-lifecycle-state-unblock-whats-freed)). Never auto-close, and always show the pairing and wait for the OK. **If which issue a PR should have closed is ambiguous, ask rather than guess**, because closing the wrong issue is worse than leaving one open.

### 2. Repair a missing link on an existing open PR
If an **open** PR should reference an issue but doesn't, add `Closes #N` to its body (editing the existing PR, not opening a new one):

```sh
gh pr edit <pr> --body-file <updated-body>
```

### 3. Checklist: tick the parent when a child closes
The task-list fallback (`- [ ] #child`) does **not** auto-tick when the child closes; native sub-issues do. When a child issue is closed, update the parent body to check its box:

```sh
gh issue view <parent> --json body -q .body   # read
gh issue edit <parent> --body-file <updated>  # write back with - [x] #child
```

### 4. Labels: advance lifecycle state, unblock what's freed
Move issues through the [lifecycle labels](#lifecycle-labels-every-mode) as PRs advance: an issue whose PR just opened → `in-review`; and, the dependency payoff, when an issue that was a **blocker** closes, find the issues whose body says `Blocked by #<it>` and swap them `blocked` → `ready`, optionally commenting that the prerequisite landed:

```sh
gh issue edit 44 --remove-label blocked --add-label ready
gh issue comment 44 --body "Unblocked: #43 (the prerequisite) merged."
gh issue edit 42 --remove-label in-review   # closing → strip the active status label; the closed state is the signal
```

As everywhere in sync, **preview each move and wait for the OK**, and never auto-relabel. If a label the map needs isn't provisioned, stop and point the user at **repokit** or the `gh label create` line, because issuekit uses labels and doesn't create them. If the repo predates this map and runs its own status scheme, follow that instead and say you did.

### 5. Hand off
**What changed.** Report issues closed, PR bodies repaired, checklists ticked, and issues advanced or **unblocked** (`blocked` → `ready`), each an action the user approved. Say plainly if nothing needed repairing; a clean sweep is a real result.

**Where it landed.** Give the **actionable set**: a table of every open issue that is `in-progress` or `ready` *after* the sync, so the user sees at a glance what's being worked and what they can pick up next in a fresh worktree:

```sh
gh issue list --state open --label in-progress --json number,title
gh issue list --state open --label ready --json number,title
```

| # | Title | Status | Priority |
|---|-------|--------|----------|
| 43 | `feat(auth): oidc login end to end` | `in-progress` | high |
| 44 | `feat(auth): sso account linking` | `ready` | medium |

List `in-progress` rows first, then `ready`, each group ordered by priority. If both sets are empty, say so instead of printing an empty table. Drop the `Priority` column when no row carries one, because an all-blank column reads as "nothing matters" when the truth is "nobody has ranked these," and the fix for that is `triage`, not a wider table.

**Next.** Crown one row from that table, naming a kit only when it's installed: an `in-progress` issue is unfinished work and outranks a fresh start (resume it in its worktree with **implementkit**), while a `ready` one is the pick-up (`start <n>`). Priority orders *within* each group and doesn't jump a `ready` issue over an `in-progress` one, because finishing beats starting, and a half-built `medium` still costs less to land than a fresh `high`. The exception is a `critical`, which means preempt by definition: crown it over in-progress work and say plainly what's being set down. Both sets empty means the tracker has nothing workable, so the move is `create` from a plan, or **plankit** if there isn't one yet.

---

## Mode: `triage`

Report first, act on approval. Never mutate the tracker just to "tidy up."

### 1. Read the tracker
Fetch `--state all` (not just open), because detecting a **closed** parent with open children, or the inverse, needs the closed issues too. Filter to open for the drift that only concerns open work.

```sh
gh issue list --state all --limit 200 --json number,title,state,labels,assignees,updatedAt,createdAt
```

Parent→child hierarchy has two representations: a task-list (`- [ ] #child`) lives in the parent's body, but **native sub-issue links live in the API, not the body**, so enumerate them with `gh api repos/{owner}/{repo}/issues/{n}/sub_issues` rather than assuming the body tells the whole story.

### 2. Flag drift
Produce a **status report**, as a table, surfacing:
- **Stale.** No update in a long while (e.g. 30–60 days; scale to the repo's pace).
- **Orphaned.** No labels, no assignee, no parent.
- **Closed-parent / open-children** (and its inverse), meaning a broken hierarchy.
- **Zombie label.** A **closed** issue still carrying a status label (`in-review`, `in-progress`, …) → strip it; the closed state is the signal.
- **Stale block.** An issue labeled `blocked` whose `Blocked by #N` target is already closed → it should be `ready` (hand the relabel to `sync`).
- **Dangling / circular dependency.** A `Blocked by #N` pointing at a missing issue, or two issues blocking each other.
- **Unmarked.** An open issue carrying no [lifecycle label](#lifecycle-labels-every-mode) at all → offer to classify it (`triage` / `needs-planning` / `ready` / `blocked`).
- **Unassessed.** An open issue carrying no [priority label](#priority-labels-every-mode) → offer to rank it. Report this as its own count rather than folding it into *Unmarked*: the two are independent gaps, and a tracker with tidy lifecycle labels and no priorities anywhere is both a common state and an invisible one if the report only ever prints one number. Exclude `wontfix` and `duplicate`, which need no rank.
- **Double-ranked.** An open issue carrying **more than one** priority label → offer to keep the highest and drop the rest. This is the failure mode the [one-at-a-time rule](#priority-labels-every-mode) exists to prevent, and it happens whenever a label is set outside this skill (the GitHub UI applies labels additively, with nothing to stop it). Keeping the highest is the safe repair: it can only ever over-rank an issue the user is about to look at anyway, where silently keeping the lowest buries work somebody explicitly escalated.
- **Stale `critical`.** An issue labeled `critical` that hasn't been updated in weeks → offer to demote it. `critical` means *preempt what's in progress*, so an untouched one is self-refuting: nobody dropped anything for it, which is the tracker saying out loud that it isn't critical. Left alone it's worse than no label at all, because it outranks everything downstream forever and trains the user to ignore the level that's supposed to be unignorable. Scale "weeks" to the repo's pace, the same way the *Stale* check does.
- **Ungrilled `ready`.** An issue labeled `ready` whose decisions clearly aren't settled (open questions in the body, no acceptance criteria) → it was promoted too early; offer to move it back to `needs-planning` so unattended workers skip it until a human grills it.
- **Missing labels**, relative to the [lifecycle map](#lifecycle-labels-every-mode) (or the repo's own scheme, if it predates it). When the map's labels aren't provisioned, say so and point at **repokit** rather than creating them.
- **Status cross-checks.** Issues whose linked PR merged but that are still open (hand off to `sync` for the actual close).

### 3. Offer fixes
For each flagged item, propose a concrete fix (relabel, reprioritize, close as stale, post a decision comment) and apply **only what the user approves**:

```sh
gh issue edit <n> --add-label <label>
gh issue edit <n> --add-label high --remove-label medium   # priority is a replace, never an add
gh issue comment <n> --body-file <decision>
gh issue close <n> --comment "Closing as stale; reopen if still relevant."
```

**Ranking an unassessed backlog is a batch, so propose it as one table**, with issue, title, and a proposed priority per row, rather than as one question per issue. Priority is comparative by nature: the user is deciding what beats what, and a table is the only shape that shows them the comparison they're actually making. Asked one at a time, twenty issues become twenty context-free judgments and every one of them comes back `medium`, which is the same as not ranking at all.

**Propose a distribution, not a wall of `high`.** A backlog where most things are `high` has no priority information in it: the label stops discriminating and every consumer falls back to whatever tiebreak sits underneath it. Aim for a shape where `critical` is empty or nearly so, `high` is a handful, and the long tail is `medium` and `low`. When your own proposal comes out top-heavy, that's a signal to re-read the issues rather than to ship the table.

**Never apply a priority the user didn't approve, even in a batch.** Ranking is the one thing in this map that can't be derived from the tracker: every other triage fix repairs a state that's provably wrong (a zombie label on a closed issue, a block whose blocker landed), where a priority is a claim about what matters that only the user can make. Approve-the-table is fine; approve-nothing-and-apply-anyway is not.

### 4. Hand off
**What changed.** Report what the report found, and which fixes you applied versus left alone. A flagged item the user declined is worth naming; it stays drift until someone decides otherwise.

**Where it landed.** Give the tracker's state after the pass, per namespace: how many open issues now carry a lifecycle label and how many are still unmarked, and how many carry a priority and how many are still unassessed. Two numbers, because a pass can genuinely fix one and leave the other untouched.

**Next.** triage only classifies; the fixes it can't make itself belong to a sibling mode, so route by what survived: issues whose PR merged but that are still open → `sync`; a stale `blocked` whose prerequisite already landed → `sync`; an issue promoted to `ready` too early → a human grill session (**grillkit** when installed) before anything unattended touches it; missing labels in either namespace → **repokit**. If the tracker came back clean, say so and point at the `ready` set, because the next move is `start` on the **highest-priority** one, not more tidying.

---

## Shared action: comment a plan or decision

Across `create` and `triage` you may post a plan excerpt or a decision onto an issue as an audit trail. It's a shared action, not a mode:

```sh
gh issue comment <n> --body-file <file>
```

Use a temp file for multi-line markdown and remove it after.

## Notes

- **Never** merge PRs, and never mutate GitHub state without showing the change and getting an OK first.
- If the repo has its own issue conventions, whether a template in `.github/ISSUE_TEMPLATE/`, a labeling scheme, or a title style visible in `gh issue list`, follow those over these defaults and say you did.
- Prefer `--body-file` over `--body` for anything multi-line; clean up temp files afterward.
- Keep issues proportional to the work: a one-line fix is one issue, not an epic with three children. Scale the breakdown to the plan's real surface area.
