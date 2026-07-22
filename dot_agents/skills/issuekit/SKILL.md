---
name: issuekit
description: >-
  Own the GitHub issue lifecycle with three modes — create issues from a plan-*.md or a description (kept independent for parallel git-worktree work, with any prerequisite labeled `blocked`), sync PR↔issue links after merge, and triage the tracker. Use when the user says "create issues from this plan", "file an issue", "sync my issues", "close the issue this PR fixed", "triage the backlog", "issuekit", or wants issues opened, reconciled, or reviewed with the gh CLI.
license: MIT
allowed-tools: Bash, Read, Edit
metadata:
  internal: false
---

# issuekit

Own the GitHub issue lifecycle through the [`gh` CLI](https://cli.github.com), in three explicit **modes**:

- **`create`** — turn a plan document or a plain description into well-formed issues, with parent→child links.
- **`sync`** — reconcile and repair the PR↔issue relationship *after* the fact (issues a merged PR should have closed, a missing link on an existing PR, an un-ticked parent checklist).
- **`triage`** — report the health of the tracker, then offer fixes you approve.

One skill, three jobs, because they're the same job at three points in a dev workflow: file the work, keep it in sync as PRs land, and keep the tracker honest.

## When this fires

The user wants to act on GitHub issues. Route to a mode from what they ask:

- **create** — "create issues from this plan", "open issues for `plan-auth.md`", "file an issue for X", "start fresh with an issue".
- **sync** — "sync my issues", "this PR merged but the issue is still open", "link this PR to #42", "tick the parent checklist".
- **triage** — "triage the backlog", "what's the state of my issues", "review open issues", "any stale issues".

**If no mode is clear, ask first.** Present the three modes as options and let the user pick before doing anything — don't guess between creating and mutating the tracker.

## Preflight (every mode)

Before any GitHub call, confirm the tooling is ready:

```sh
gh --version        # gh installed?
gh auth status      # authenticated?
gh repo view --json nameWithOwner -q .nameWithOwner   # inside a repo?
```

- If `gh` is missing or unauthenticated, say so and point to `https://cli.github.com` / `gh auth login` — don't work around it.
- **No shell or `gh` at all** (e.g. a browser-based agent)? You can't call `gh`. Instead do the reasoning from what the user provides and **print the exact `gh` commands** for them to run themselves — issue bodies as codeblocks, `gh issue create …` / `gh issue close …` lines ready to paste.

**Safety stance — the whole skill.** Creating, closing, relabeling issues and editing PR bodies are outward-facing mutations. **Preview every mutation and get an OK before it runs — nothing changes on GitHub unprompted.** Never merge PRs.

## Title convention (every issue this skill creates)

Issue titles follow the same shape as [commitkit](https://www.conventionalcommits.org)'s commit subjects, so the tracker and the git log read as one workflow. **Format:**

```
type(scope): short imperative summary
```

Pick the `type` from what the issue delivers, not the files it touches — the set mirrors commitkit's, with one addition (`epic`) for parent issues:

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

Rules — apply them to **every** title you generate:

- **`(scope)` is mandatory** — the module, package, directory, or feature area the work belongs to (`feat(auth): …`). For genuinely global work (repo-wide config, tooling, cross-cutting cleanup) fall back to `repo`: `chore(repo): …`.
- **Entirely lowercase** — never capitalize any word in the title, including the first. Proper nouns and acronyms (`OIDC`, `SSO`, `CI`) are the only exceptions.
- **Imperative mood**, stating the *effect* ("add sso login"), not the activity ("changes to auth"). **No trailing period.** Keep it concise.
- A parent epic and its children **share the scope** so the group is obvious in the list: `epic(auth): …` over `feat(auth): oidc login end to end`, `feat(auth): sso account linking`.

If the repo has its own issue-title style (visible in `gh issue list` or an `.github/ISSUE_TEMPLATE/`), follow that instead and say you did — see [Notes](#notes).

---

## Lifecycle labels (every mode)

issuekit tracks where an issue sits in the workflow with a small, **flat** set of status labels. It **uses** these labels — it never creates them. Provisioning labels is the job of a companion skill, **repokit**. When a label this skill needs is absent from the repo, **stop and tell the user how to add it** (run `repokit`, or the exact `gh label create` line) rather than creating it yourself or skipping silently.

The canonical map — exactly one **status** label is active at a time, moving left to right through the workflow; the three side-exits apply whenever they fit. This table is the **shared contract with [repokit](https://www.skills.sh)**, the skill that provisions these labels — repokit mirrors this exact set (names, colors, meanings); if you change one table, change the other so they never drift:

| label | color | means | typically set by |
|-------|-------|-------|------------------|
| `triage` | `FBCA04` | filed, not yet assessed or broken down | create (ad-hoc), triage |
| `ready` | `0E8A16` | specified and **independent** — safe to take into its own git worktree now | issuekit create |
| `blocked` | `D93F0B` | has an unmet prerequisite; the blocker is named in the body as `Blocked by #N` | issuekit create / sync |
| `in-progress` | `1D76DB` | actively being worked in a worktree | the implement step / a human |
| `in-review` | `5319E7` | a PR is open, awaiting review or merge | a PR-authoring skill / sync |
| `needs-info` | `D4C5F9` | stalled pending more detail before it can proceed | triage |
| `wontfix` | `FFFFFF` | will not be actioned | triage |
| `duplicate` | `CFD3D7` | superseded by another issue | triage |

A **closed** issue needs no `done` label — the closed state is the signal.

**`ready` vs `blocked` is the parallel-work pair.** issuekit sizes and sequences issues so each can be picked up in its own worktree with no ordering constraint — those get `ready`. The exception, an issue that genuinely can't start until another lands, gets `blocked` plus a `Blocked by #N` line in its body: the label says *that* it's blocked, the body says *by what*. `gh issue list --label ready` is then the exact set the user can fan out in parallel right now.

**Type lives in the title, not a label.** Issues already carry `feat(scope):` / `fix(scope):` per the [title convention](#title-convention-every-issue-this-skill-creates), so this map has no `type:` labels — only lifecycle status.

**When a needed label is missing**, check once with `gh label list`, then report the gap instead of mutating around it:

> Label `blocked` isn't in this repo. Provision the workflow labels with **repokit**, or add just this one:
> `gh label create blocked --color D93F0B --description "has an unmet prerequisite (see 'Blocked by #N' in the body)"`

Apply a label only once it exists (`gh issue edit <n> --add-label <label>`) and — like every mutation in this skill — [preview it and get an OK first](#preflight-every-mode).

---

## Mode: `create`

Turn work into issues. Two inputs — a plan file (the main path) or a plain description (start fresh).

### 1. Find the input
- **Plan path:** a `plan-*.md`. Resolve it by precedence: an explicit path in the prompt → the newest `docs/plans/plan-*.md` → ask which plan.
- **Ad-hoc path:** a plain description with no plan. This is the "start fresh, just file it" case → one well-formed issue.

### 2. Decompose a plan into a proposed breakdown
Read the plan's structure — phases, milestones, tasks — and decide the shape:
- a **parent epic + N child issues** when the plan has distinct sub-tasks worth tracking separately, or
- a **flat list** (or single issue) when it doesn't.

Four principles govern the breakdown — apply them **before** you present anything:

- **Fewest issues by default.** Actively look for scopes where several related tasks can collapse into **one issue with a checklist** instead of separate issues. Merge aggressively; only split into its own issue/sub-issue when a task is genuinely independent — different lifecycle, owner, or PR. Default to the *smallest* number of issues and sub-issues that still tracks the work honestly. The user can always ask to split one further; starting consolidated and splitting on request beats starting fragmented.
- **Vertical slices.** Size each issue/sub-issue so it completes **one testable feature end to end** whenever possible — a slice a person could verify on its own — rather than a horizontal layer (e.g. "all the DB models", "all the endpoints") that isn't demonstrable until other issues land. Prefer "user can log in with SSO" over separate "add OIDC table" / "add OIDC route" / "add OIDC UI" issues; fold those layers into the one vertical slice as checklist items. Size it, too, so one slice **fits in a single fresh agent context / worktree session** — if a slice couldn't plausibly be finished in one sitting, it's a sign to split it.
- **Independent by default.** Size and sequence issues so each can be picked up in its own git worktree and worked **in parallel** — no issue waiting on another. When two candidate slices share state (a migration one creates and another consumes, an API contract one produces), first try to **design the dependency away**: fold them into one issue, or resequence so the shared piece ships inside the prerequisite. Only when a real ordering constraint survives do you record it — the dependent gets [`blocked`](#lifecycle-labels-every-mode) and a `Blocked by #N` line, everything else gets `ready`. This is what makes the tracker safe to fan out across worktrees.
- **Prefactor first.** Before slicing the feature, look for a simplifying refactor that makes the real change trivial — *"make the change easy, then make the easy change."* File that refactor as its own `ready` issue (behavior-preserving → `refactor(scope):`) that the feature slices then build on. A clean prefactor often *removes* a dependency that would otherwise force a `blocked` chain, so it earns its keep even as an extra issue.

**Wide mechanical refactors.** When a change has broad blast radius and genuinely can't be one vertical slice — renaming a shared column, retyping a symbol used everywhere — don't file it as one giant issue. Sequence it **expand → migrate → contract**:

- **expand** — add the new form alongside the old; nothing breaks yet. `ready`.
- **migrate** — update call sites in batches by area, each batch its own issue [`blocked`](#lifecycle-labels-every-mode) by the expand issue (`Blocked by #<expand>`). The batches are independent of *each other* — fan them out in parallel.
- **contract** — delete the old form once nothing uses it, `blocked` by all the migrate batches.

This turns one un-sliceable change into a fan of mostly-parallel issues with honest `Blocked by #N` edges, and reuses the existing `ready`/`blocked` machinery — no new labels. If the batches can't each stay green on their own, add one final integrate-and-verify issue blocked by them all.

**Milestones are opt-in.** Do **not** create GitHub milestones by default — map a plan's phases onto issues and checklists instead. Only when the user **explicitly asks** for milestones (or points at a repo that already uses them) should you create one (`gh api repos/{owner}/{repo}/milestones`, then `gh issue create --milestone <title>`) and attach issues to it. Absent that ask, never introduce a milestone the user would then have to maintain.

Present the proposal as a **preview table** and stop for approval — do **not** create anything yet:

| # | Type | Title | Parent | Depends on | Checklist |
|---|------|-------|--------|-----------|-----------|
| 1 | epic | `epic(auth): add sso login` | — | — | — |
| 2 | child | `feat(auth): oidc login end to end` | #1 | — | provider · session · token refresh · UI |
| 3 | child | `feat(auth): sso account linking` | #1 | #2 | link existing · unlink · conflict handling |

Titles follow the [title convention](#title-convention-every-issue-this-skill-creates): `type(scope): summary`, lowercase, the epic and its children sharing the `auth` scope. Each child is a vertical slice with its layers folded into a checklist, not one issue per layer. The **Depends on** column is where independence is decided out loud: a blank cell means the issue is `ready` — pick it up in its own worktree now — while a `#N` means it's `blocked` by that issue (row 3 waits on row 2). Keep the column as empty as honesty allows; a mostly-blank column is a tracker the user can fan out in parallel. Let the user add, drop, retitle, reparent, **resequence to break a dependency**, or **split** any row before you proceed — offer splitting explicitly when a slice is large. This guard is the point — never spray a repo with auto-generated issues.

For an **ad-hoc** description, skip the table: draft one issue (title + body) and confirm it before creating.

### 3. Create the issues
**Guard against duplicates first.** create is the workflow's entry point and gets re-invoked — running it twice on one plan must not file a second set. Before creating, list existing issues and skip (or flag for the user) any whose title already matches:

```sh
gh issue list --state all --limit 200 --json number,title,state
```

Then write each issue with a title in the [`type(scope): summary` convention](#title-convention-every-issue-this-skill-creates) and a body that carries the relevant slice of the plan — context, acceptance criteria, and any decisions. Create parents before children so child bodies can reference them.

Two conventions for the body:

- **Write acceptance criteria as `- [ ]` checkboxes** — a concrete, verifiable definition of done for *this* issue. (Distinct from the sub-issue/parent checklist below, which tracks child issues.)
- **Don't hard-code file paths** — they go stale as the branch evolves; describe the change by behavior and area instead. The one exception is a **decision-rich snippet** (a schema, state machine, type, reducer) where the decision *is* the code — include it, trimmed to just the substantive part.

```sh
gh issue create --title "epic(auth): add sso login" --body-file <bodyfile>
```

Use a temp file for each body (multi-line markdown through `--body` is flaky) and clean it up after.

### 4. Link parents → children
Try GitHub's **native sub-issues** first, then fall back:

```sh
# Native (preferred): attach a child to its parent via the sub-issues API.
# sub_issue_id is the child's DATABASE id (an integer) — NOT the GraphQL node id
# that `gh issue view --json id` returns. Resolve it from the REST endpoint:
child_id=$(gh api repos/{owner}/{repo}/issues/{child_number} --jq .id)
# Attach it — use -F (typed integer), not -f (which would send a string and be rejected):
gh api --method POST repos/{owner}/{repo}/issues/{parent_number}/sub_issues \
  -F sub_issue_id="$child_id"
```

If that call fails — sub-issues disabled, older GitHub Enterprise, or insufficient permissions — **fall back** to a task-list checklist in the parent body and **tell the user which path was used**:

```markdown
### Sub-issues
- [ ] #43 wire OIDC provider
- [ ] #44 session + token refresh
```

### 5. Label lifecycle state and record dependencies
Apply the [lifecycle labels](#lifecycle-labels-every-mode) so the fresh issues advertise their state: every independent issue gets `ready`, every dependent one gets `blocked` plus a `Blocked by #N` line written into its body naming the prerequisite. Confirm each label exists first (`gh label list`) — if one is missing, stop and point the user at **repokit** or the `gh label create` line rather than creating it yourself.

```sh
gh issue edit 43 --add-label ready
gh issue edit 44 --add-label blocked   # body carries: Blocked by #43
```

Preview the label set alongside the issues and get an OK before applying — a mutation like any other.

### 6. Write the issue numbers back into the plan
Once issues exist, annotate the source `plan-*.md` so it stays the source of truth — add the ref next to each task it maps to:

```markdown
### Phase 2 — auth (#41)
- OIDC provider (#43)
- session + token refresh (#44)
```

Use `Edit` for this. For an ad-hoc issue with no plan file, skip this step.

### 7. Report
Print a table of what you created — number, title, parent, URL, and lifecycle label — and call out the **`ready` set** (issues the user can start in parallel worktrees right now) versus the **`blocked` set** (and what each waits on). Note whether links used native sub-issues or the task-list fallback, and that the plan was annotated.

---

## Mode: `sync`

Reconcile and repair the PR↔issue relationship. **Sync deliberately does not write the forward `Closes #N` link onto a fresh PR** — that belongs to the PR-authoring step (a prkit-style skill) at open time. Sync only earns its place where the automatic chain *broke*:

| Who | Owns |
|-----|------|
| PR-authoring skill | write `Closes #N` into a **new** PR at open time (forward, happy path) |
| **issuekit sync** | reconcile drift after merge, repair a missing link on an **existing** PR, tick parent checklists, advance lifecycle labels and unblock dependents |

### 1. Reconcile — merged PR whose issue never closed
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

Closing is a lifecycle transition too — strip any active status label (`in-review`, `in-progress`, …) in the same action so a closed issue never carries a stale status (see [step 4](#4-labels--advance-lifecycle-state-unblock-what-s-freed)). Never auto-close — always show the pairing and wait for the OK. **If which issue a PR should have closed is ambiguous, ask rather than guess** — closing the wrong issue is worse than leaving one open.

### 2. Repair — missing link on an existing open PR
If an **open** PR should reference an issue but doesn't, add `Closes #N` to its body (editing the existing PR, not opening a new one):

```sh
gh pr edit <pr> --body-file <updated-body>
```

### 3. Checklist — tick the parent when a child closes
The task-list fallback (`- [ ] #child`) does **not** auto-tick when the child closes; native sub-issues do. When a child issue is closed, update the parent body to check its box:

```sh
gh issue view <parent> --json body -q .body   # read
gh issue edit <parent> --body-file <updated>  # write back with - [x] #child
```

### 4. Labels — advance lifecycle state, unblock what's freed
Move issues through the [lifecycle labels](#lifecycle-labels-every-mode) as PRs advance: an issue whose PR just opened → `in-review`; and — the dependency payoff — when an issue that was a **blocker** closes, find the issues whose body says `Blocked by #<it>` and swap them `blocked` → `ready`, optionally commenting that the prerequisite landed:

```sh
gh issue edit 44 --remove-label blocked --add-label ready
gh issue comment 44 --body "Unblocked: #43 (the prerequisite) merged."
gh issue edit 42 --remove-label in-review   # closing → strip the active status label; the closed state is the signal
```

As everywhere in sync, **preview each move and wait for the OK** — never auto-relabel. If a label the map needs isn't provisioned, stop and point the user at **repokit** or the `gh label create` line — issuekit uses labels, it doesn't create them. If the repo predates this map and runs its own status scheme, follow that instead and say you did.

### 5. Report
Summarize what changed: issues closed, PR bodies repaired, checklists ticked, issues advanced or **unblocked** (`blocked` → `ready`) — each an action the user approved.

---

## Mode: `triage`

Report first, act on approval. Never mutate the tracker just to "tidy up."

### 1. Read the tracker
Fetch `--state all` (not just open) — detecting a **closed** parent with open children, or the inverse, needs the closed issues too. Filter to open for the drift that only concerns open work.

```sh
gh issue list --state all --limit 200 --json number,title,state,labels,assignees,updatedAt,createdAt
```

Parent→child hierarchy has two representations: a task-list (`- [ ] #child`) lives in the parent's body, but **native sub-issue links live in the API, not the body** — enumerate them with `gh api repos/{owner}/{repo}/issues/{n}/sub_issues` rather than assuming the body tells the whole story.

### 2. Flag drift
Produce a **status report** — a table — surfacing:
- **Stale** — no update in a long while (e.g. 30–60 days; scale to the repo's pace).
- **Orphaned** — no labels, no assignee, no parent.
- **Closed-parent / open-children** (and its inverse) — broken hierarchy.
- **Zombie label** — a **closed** issue still carrying a status label (`in-review`, `in-progress`, …) → strip it; the closed state is the signal.
- **Stale block** — an issue labeled `blocked` whose `Blocked by #N` target is already closed → it should be `ready` (hand the relabel to `sync`).
- **Dangling / circular dependency** — a `Blocked by #N` pointing at a missing issue, or two issues blocking each other.
- **Unmarked** — an open issue carrying no [lifecycle label](#lifecycle-labels-every-mode) at all → offer to classify it (`triage` / `ready` / `blocked`).
- **Missing labels** — relative to the [lifecycle map](#lifecycle-labels-every-mode) (or the repo's own scheme, if it predates it); when the map's labels aren't provisioned, say so and point at **repokit** rather than creating them.
- **Status cross-checks** — issues whose linked PR merged but that are still open (hand off to `sync` for the actual close).

### 3. Offer fixes
For each flagged item, propose a concrete fix — relabel, reprioritize, close as stale, post a decision comment — and apply **only what the user approves**:

```sh
gh issue edit <n> --add-label <label>
gh issue comment <n> --body-file <decision>
gh issue close <n> --comment "Closing as stale; reopen if still relevant."
```

### 4. Report
Recap what the report found and what was changed vs. left alone.

---

## Shared action: comment a plan or decision

Across `create` and `triage` you may post a plan excerpt or a decision onto an issue as an audit trail. It's a shared action, not a mode:

```sh
gh issue comment <n> --body-file <file>
```

Use a temp file for multi-line markdown and remove it after.

## Notes

- **Never** merge PRs, and never mutate GitHub state without showing the change and getting an OK first.
- If the repo has its own issue conventions — a template in `.github/ISSUE_TEMPLATE/`, a labeling scheme, a title style visible in `gh issue list` — follow those over these defaults and say you did.
- Prefer `--body-file` over `--body` for anything multi-line; clean up temp files afterward.
- Keep issues proportional to the work: a one-line fix is one issue, not an epic with three children. Scale the breakdown to the plan's real surface area.
