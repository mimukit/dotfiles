---
name: issuekit
description: >-
  Own the GitHub issue lifecycle in five modes: create issues from a plan or description, start a `ready` or `stacked` issue into its own worktree, close one out once its PR merges, sync PR↔issue links and dependents after merge, and triage the tracker for lifecycle, priority, and title gaps. Use when the user says "create issues from this plan", "file an issue", "start issue #42", "close #42", "sync my issues", "triage the backlog", "set the priority on #42", "#42 is grilled, mark it ready", or "fix the titles on these issues".
license: MIT
allowed-tools: Bash, Read, Edit, Write, Skill
metadata:
  internal: false
---

# issuekit

Own the GitHub issue lifecycle through the [`gh` CLI](https://cli.github.com), in five explicit **modes**:

- **`create`.** Turn a plan document or a plain description into well-formed issues.
- **`start`.** Take a `ready` or `stacked` issue into its own worktree and flip it `in-progress`.
- **`close`.** Once its PR has merged, close the issue, unblock what it was holding up, and tear the worktree down.
- **`sync`.** Reconcile and repair the PR↔issue relationship *after* the fact (issues a merged PR should have closed, a missing link on an existing PR, a dependent still marked `blocked` by an issue that landed).
- **`triage`.** Report the health of the tracker, then apply the fixes you approve, including the `needs-planning → ready` promotion once a grill settled an issue.

One skill, five jobs, because they're the same job at five points in a dev workflow: file the work, pick it up, land it, keep everything in sync as PRs merge, and keep the tracker honest.

**`close` vs `sync`.** They do overlapping tracker work and the split is by *scope*, not mechanism: `close` lands **one named issue** whose PR you know merged, and is the only mode that touches the filesystem (the worktree teardown). `sync` sweeps the **whole tracker** for drift after the fact, meaning issues a merged PR should have closed but didn't, missing links, and dependents still marked `blocked` by work that landed, and it never touches a worktree. `close` reuses `sync`'s reconciliation rather than restating it.

## When this fires

The user wants to act on GitHub issues. Route to a mode from what they ask:

- **create.** "Create issues from this plan", "open issues for `plan-auth.md`", "file an issue for X", "file this as an issue", "open a GitHub issue", "log this as a task", "add this to the backlog", "make issues for these TODOs".
- **start.** "Start issue #42", "begin #42", "pick up #42", "spin up a worktree for #42", "I'm working on 42 now".
- **close.** "Close #42", "close out #42", "wrap up #42 now the PR merged", "tear down #42's worktree", "#42 landed, clean it up".
- **sync.** "Sync my issues", "this PR merged but the issue is still open", "link this PR to #42", "unblock what #42 was holding up".
- **triage.** "Triage the backlog", "what's the state of my issues", "review open issues", "any stale issues", "prioritize my backlog", "set the priority on #42", "nothing has a priority", "relabel #42", "rename issue #42", "fix the titles on these issues", "these titles don't follow the convention", "#42 is grilled, mark it ready".

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

**Label writes are exempt in `create`, `start`, `close`, and `sync`, for every caller.** Adding or removing a label on an issue or a PR runs straight through, with no preview and no prompt, whether a person is at the keyboard or an orchestrator drives the run. This covers both namespaces, [lifecycle](#lifecycle-labels-every-mode) and [priority](#priority-labels-every-mode). A label is cheap, visible, and reversible with one command, so a prompt on each write costs more attention than the write is worth, and a declined write leaves the tracker lying about work that already happened. **State every label write in the preview that accompanies it, and report what the labels became in the hand-off**, so the change is still auditable.

The exemption reaches the labels and nothing else. Every other outward-facing mutation keeps the rule above: `create` previews the issues it files, `close` previews the close and the worktree teardown, and `sync` previews each pairing and each body edit. **`triage` is outside the exemption.** Its label writes record no work that happened; each is a judgment the report proposes (a classification, a rank, a promotion), so `triage` reports first and applies every fix, labels included, only on the user's approval. Never merge PRs.

## Title convention (every issue this skill creates)

Issue titles follow the same shape as commitkit's commit subjects and the [Conventional Commits specification](https://www.conventionalcommits.org), so the tracker and the git log read as one workflow. **Format:**

```
type(scope): short imperative summary
```

Pick the `type` from what the issue delivers, not the files it touches. The set is commitkit's, unchanged:

| type | when |
|------|------|
| `feat` | a new capability the user can see |
| `fix` | a bug fix |
| `hotfix` | an urgent fix patched straight onto the base branch |
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
- **Title the whole issue, not its first phase.** A multi-phase issue names the capability it delivers end to end (`feat(auth): add sso login`), and its phases live in the body. A title that reads like one phase is a sign the issue was sliced too thin.

**A hotfix needs no issue before the branch.** Urgent work that patches the base branch directly starts from the symptom: somebody cuts a `hotfix-<slug>` branch and opens a `hotfix(scope):` pull request without waiting for the tracker. So no mode here gates a hotfix, and `start` is not on its path. When the user files one after the fact for the record, title it `hotfix(scope): …`, label it `in-review` when its PR is already open, and never label it `ready`, because `ready` promises work nobody has begun.

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
| `blocked` | `D93F0B` | has an unmet prerequisite that has not started | issuekit create / sync |
| `stacked` | `006B75` | its prerequisite has an open PR, so it is workable now on a branch stacked on that one | prkit / issuekit sync |
| `in-progress` | `1D76DB` | actively being worked in a worktree | issuekit start |
| `in-review` | `5319E7` | a PR is open, awaiting review or merge | a PR-authoring skill / sync |
| `needs-info` | `D4C5F9` | stalled pending more detail before it can proceed | triage |
| `wontfix` | `FFFFFF` | will not be actioned | triage |
| `duplicate` | `CFD3D7` | superseded by another issue | triage |

A **closed** issue needs no `done` label, because the closed state is the signal.

**`ready` vs `blocked` is the parallel-work pair.** issuekit sizes and sequences issues so each can be picked up in its own worktree with no ordering constraint, and those get `ready`. The exception, an issue that genuinely can't start until another lands, gets `blocked` plus a recorded dependency naming the prerequisite. `gh issue list --label ready` is then the exact set the user can fan out in parallel right now.

**`blocked` vs `stacked` splits waiting from stackable, and that split is the point.** A prerequisite nobody has started is a real wait, and its dependent stays `blocked`. A prerequisite that is *built, pushed, and sitting in an open PR* is not a wait at all: the code exists, so the dependent can be worked right now on a branch cut from the prerequisite's branch, and its PR targets that branch instead of trunk. That issue is `stacked`. Collapsing the two states is what makes a solo project idle, because the author is waiting on a review only they can do.

`stacked` is a **stored** label rather than a computed state, so it earns the same `gh issue list --label stacked` fan-out that `ready` has. A stored label can go stale, so it never gates anything on its own: [`start` re-checks the prerequisite's PR live](modes/start.md#1-guard-refuse-anything-not-ready-or-stacked) before it cuts a branch.

### Recording a dependency

**GitHub's native issue dependencies are the source of truth.** Write the edge with `gh issue edit`, and read it back as structured data rather than by parsing prose:

```sh
gh issue edit 44 --add-blocked-by 43
gh issue list --state open --json number,title,labels,blockedBy,blocking
```

Keep writing a `Blocked by #N` line in the body as well, because a person reading the issue should see what it waits on without opening a second view. **The line is prose, not the store.** When the two disagree, the native edge wins and the line gets repaired.

The flags need `gh` 2.94.0 or newer. **Below that, degrade rather than refuse:** write the body line only, and say once that the native edge was skipped and why. These labels and this workflow have to keep working on whatever `gh` the machine has.

**`needs-planning` vs `ready` is the human-gate pair.** `ready` means specified enough to work **unattended**, so an agent (or an orchestrator like afkkit) can take it straight to a PR without a human. `needs-planning` means a human plan/grill session is still owed before the issue is workable at all. An issue earns `ready` only once its decisions are settled by a grill; see [the grill gate at creation](modes/create.md#4-label-lifecycle-state-and-priority-and-record-dependencies). `gh issue list --label needs-planning` is then the exact set that still needs the human, the mirror of the `ready` fan-out set.

**Type lives in the title, not a label.** Issues already carry `feat(scope):` / `fix(scope):` per the [title convention](#title-convention-every-issue-this-skill-creates), so this map has no `type:` labels, only lifecycle status.

**When a needed label is missing**, check once with `gh label list`, then report the gap instead of mutating around it:

> Label `blocked` isn't in this repo. Provision the workflow labels with **repokit**, or add just this one:
> `gh label create blocked --color D93F0B --description "has an unmet prerequisite that has not started"`

Apply a label only once it exists (`gh issue edit <n> --add-label <label>`). The write itself needs no prompt, per [the label exemption](#preflight-every-mode); name it in the preview it rides with and report it in the hand-off.

### Promoting a dependent

**One transition rule sets a dependent's label, and every mode that moves or checks a dependent applies it.** When a prerequisite's state changes, recompute each dependent's label from **all** of its open prerequisites, never from the one that just moved. Issue C depends on A and B: A merging leaves C `blocked` while B has not started.

Find the dependents through the native edge, the store named in [Recording a dependency](#recording-a-dependency), and read each one's full prerequisite set the same way:

```sh
gh issue view 43 --json blocking -q '[.blocking[].number]'      # who waits on #43
gh issue view 44 --json blockedBy,labels                          # everything #44 waits on
```

Below `gh` 2.94.0, read the `Blocked by #N` body lines instead and say once that the native edge was unavailable. Then take the first row that matches:

| open prerequisites | new label |
|---|---|
| none | `ready` |
| every one has an open PR, and those PRs form one chain (each PR's base is the next one's head) | `stacked`, on the top PR of that chain |
| every one has an open PR, and the PRs do not form one chain | keep the current label, and report the incompatible parents |
| at least one has no open PR | `blocked` |

- **A prerequisite's change moves only `blocked` and `stacked` dependents.** A `needs-planning` dependent keeps its label, because the grill gate holds it, not the dependency. An `in-progress` or `in-review` dependent keeps its label, because its work has started.
- **A layer has one parent branch.** When the open PRs sit on separate branches, no single base satisfies them all. Name each candidate parent PR in the report and let the user decide; never pick one.
- **Every move is a replace.** Remove the current lifecycle label in the same call that adds the new one: `gh issue edit 44 --remove-label blocked --add-label ready`.
- **A PR query that fails leaves the dependent alone.** Report it as unknown and name the failed call; an error is not evidence that no PR exists.

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

## The modes

The mode bodies live in one file each under `modes/`. Route with [When this fires](#when-this-fires), read that one file, and follow it. Everything above this line applies to every mode and is not restated in the mode files.

- Mode `create` → read [modes/create.md](modes/create.md), then follow it.
- Mode `start` → read [modes/start.md](modes/start.md), then follow it.
- Mode `close` → read [modes/close.md](modes/close.md), then follow it.
- Mode `sync` → read [modes/sync.md](modes/sync.md), then follow it.
- Mode `triage` → read [modes/triage.md](modes/triage.md), then follow it.

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
- Keep issues proportional to the work: a one-line fix is one issue with one acceptance criterion, not a phased build-out. Scale the body to the plan's real surface area, and let a large plan stay one large issue.
