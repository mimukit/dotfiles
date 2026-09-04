---
name: issuekit
description: >-
  Own the GitHub issue lifecycle in five modes: create issues from a plan or description, start a `ready` issue into its own worktree, close one out once its PR merges, sync PR↔issue links after merge, and triage the tracker for lifecycle and priority gaps. Use when the user says "create issues from this plan", "file an issue", "start issue #42", "close #42", "sync my issues", "triage the backlog", or "set the priority on #42". It runs the tracker only; it writes no plan and no code.
license: MIT
allowed-tools: Bash, Read, Edit, Write, Skill
metadata:
  internal: false
---

# issuekit

Own the GitHub issue lifecycle through the [`gh` CLI](https://cli.github.com), in five explicit **modes**:

- **`create`.** Turn a plan document or a plain description into well-formed issues.
- **`start`.** Take a `ready` issue into its own worktree and flip it `in-progress`.
- **`close`.** Once its PR has merged, close the issue, unblock what it was holding up, and tear the worktree down.
- **`sync`.** Reconcile and repair the PR↔issue relationship *after* the fact (issues a merged PR should have closed, a missing link on an existing PR, a dependent still marked `blocked` by an issue that landed).
- **`triage`.** Report the health of the tracker, then offer fixes you approve.

One skill, five jobs, because they're the same job at five points in a dev workflow: file the work, pick it up, land it, keep everything in sync as PRs merge, and keep the tracker honest.

**`close` vs `sync`.** They do overlapping tracker work and the split is by *scope*, not mechanism: `close` lands **one named issue** whose PR you know merged, and is the only mode that touches the filesystem (the worktree teardown). `sync` sweeps the **whole tracker** for drift after the fact, meaning issues a merged PR should have closed but didn't, missing links, and dependents still marked `blocked` by work that landed, and it never touches a worktree. `close` reuses `sync`'s reconciliation rather than restating it.

## When this fires

The user wants to act on GitHub issues. Route to a mode from what they ask:

- **create.** "Create issues from this plan", "open issues for `plan-auth.md`", "file an issue for X", "file this as an issue".
- **start.** "Start issue #42", "begin #42", "pick up #42", "spin up a worktree for #42", "I'm working on 42 now".
- **close.** "Close #42", "close out #42", "wrap up #42 now the PR merged", "tear down #42's worktree", "#42 landed, clean it up".
- **sync.** "Sync my issues", "this PR merged but the issue is still open", "link this PR to #42", "unblock what #42 was holding up".
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

**Label writes are exempt, in every mode and for every caller.** Adding or removing a label on an issue or a PR runs straight through, with no preview and no prompt, whether a person is at the keyboard or an orchestrator drives the run. This covers both namespaces, [lifecycle](#lifecycle-labels-every-mode) and [priority](#priority-labels-every-mode). A label is cheap, visible, and reversible with one command, so a prompt on each write costs more attention than the write is worth, and a declined write leaves the tracker lying about work that already happened. **State every label write in the preview that accompanies it, and report what the labels became in the hand-off**, so the change is still auditable.

The exemption reaches the labels and nothing else. Every other outward-facing mutation keeps the rule above: `create` previews the issues it files, `close` previews the close and the worktree teardown, `sync` previews each pairing and each body edit, and `triage` previews every close and comment it proposes. Never merge PRs.

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
> `gh label create blocked --color D93F0B --description "has an unmet prerequisite (see 'Blocked by #N' in the body)"`

Apply a label only once it exists (`gh issue edit <n> --add-label <label>`). The write itself needs no prompt, per [the label exemption](#preflight-every-mode); name it in the preview it rides with and report it in the hand-off.

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
