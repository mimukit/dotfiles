## Mode: `start`

Pick an issue up: guard that it's actually workable, get it a worktree, and move it to `in-progress`. This is the moment the tracker and the filesystem meet, and it is deliberately thin: the tracker half is issuekit's, the worktree half is gitkit's, and there is nothing in between.

### 1. Guard: refuse anything not `ready` or `stacked`

**Never start an issue that isn't labeled `ready` or `stacked`.**

```sh
gh issue view <n> --json labels,title,state,blockedBy
```

This one guard carries more weight than its size suggests, and it is the reason `start` lives here rather than in a worktree skill. An issue only reaches `ready` two ways: a human grilled its decisions settled, or issuekit `sync` promoted it `blocked → ready` when its prerequisite landed. So refusing everything else enforces **both the dependency graph and the human-grill gate for free**: no unattended worker can get ahead of the tracker, and none can get ahead of human judgment.

**`stacked` passes the same gate for the same reason, and then earns a second check.** An issue reaches `stacked` only from `blocked`, and it reached `blocked` from a grilled breakdown, so the human-grill gate is already satisfied. What is *not* satisfied is the dependency half, because the prerequisite has not landed, it is merely in flight. So a `stacked` issue gets a live verification before anything is cut:

```sh
gh pr list --search "<blocker>" --state open --json number,headRefName,state
```

**The label is discovery; this check is the gate.** `stacked` is written by another skill at PR-open time and repaired by `sync`, so between those moments it can be wrong in exactly the way that costs the most: the PR was closed unmerged, or it merged and its branch was deleted. Cutting a layer from a branch that is gone fails much later and far from its cause.

Refuse a `stacked` issue when the prerequisite's PR is closed, merged, or missing, and say which:

- **PR merged** → the prerequisite landed, so this is no longer stacked work. Point at `sync`, which promotes it `stacked → ready` and lets a normal start cut from the base ref.
- **PR closed unmerged** → the prerequisite was abandoned. The issue is `blocked` again, not stackable. Say so and stop.
- **No PR found** → the label is drift. Point at `sync` to repair it.

Never soften this into a warning. A refusal here costs one command; a worktree cut from a dead branch costs a confusing debugging session days later.

That last part is load-bearing for an orchestrator that calls `start` itself with nobody watching (afkkit does exactly this, as the first step of every run). The gate does not depend on who types the command: it's the `ready` *label* that carries the human's judgment, earned upstream at the grill, and nothing that calls `start` can award it. So refuse on the label alone, and never soften the guard because the caller sounds confident, names a plan, or says it's fine.

Refuse with the reason, not a bare error:

- **`needs-planning`** → the decisions aren't settled; it needs a human grill session first.
- **`blocked`** → name the prerequisite and its state. When that prerequisite turns out to have an open PR, the issue should be `stacked`, so point at `sync` to promote it rather than starting it here.
- **`in-progress`** → it's already started; go to the adopt path below rather than treating this as a failure.
- **closed, or no lifecycle label** → say which, and offer `triage` to classify it.

### 2. Derive the branch name

**gitkit owns branch naming**, so hand it the issue number and title and use what comes back. For an issue titled in the [`type(scope): summary` convention](../SKILL.md#title-convention-every-issue-this-skill-creates), that yields `issue-<n>-<slug>`: the prefix stripped, the summary kebab-cased and capped. Don't re-derive the shape here; a second copy of the slug rules drifts from the one gitkit uses to *find* the worktree later, and then lookup silently stops matching.

A `stacked` issue takes the same branch name. A layer is an ordinary branch, and it is named after the issue it builds, not after its position in the stack.

### 3. Get the worktree from gitkit, create or adopt

Call gitkit for the branch. It looks the branch up first and **adopts an existing worktree** if there is one, creating a fresh one off the resolved base ref only when there is none. That is what makes `start` safe to re-run: the re-run path is real (an issue escalated back to `needs-planning`, grilled, and picked up again), and it must never recreate, never error, and never disturb work already sitting in the worktree.

**A `stacked` issue passes gitkit one extra fact: the base is the prerequisite's head branch**, taken from the PR the guard just verified, rather than the repo's base ref. gitkit states this as the one deliberate exception to its sibling-branch ban and gives the layer its own worktree, so nothing else about this step changes. Ask gitkit to add the layer to the stack so GitHub renders the chain; without the stack extension it falls back to a plain branch off the parent, which is the same topology with no stack map.

issuekit does not choose the path, the base ref, or the git commands. If gitkit isn't installed, say so and stop rather than improvising a worktree convention, because a worktree in the wrong place is worse than none, since everything downstream then looks in the right place and finds nothing.

### 4. Flip the label `ready → in-progress`

```sh
gh issue edit <n> --remove-label ready --add-label in-progress
gh issue edit <n> --remove-label stacked --add-label in-progress   # the stacked path
```

**Run it without asking**, per [the label exemption](../SKILL.md#preflight-every-mode), which applies to every caller. Report the flip in the hand-off rather than proposing it first. If the issue was already `in-progress` (the adopt path), leave the label alone and say so.

A `stacked` issue flips exactly the same way. If either label is missing from the repo, [report the gap](../SKILL.md#lifecycle-labels-every-mode) and point at **repokit**, because the exemption skips the prompt, never the provisioning check.

### 5. Hand off

**What changed.** Report the label move (`ready → in-progress`, or that it was left alone on the adopt path).

**Where it landed.** Give the branch and the worktree path, and whether it was created fresh or adopted.

**Next.** The ground is prepared and nothing has been built, so the next move is always *switch into that worktree and start there*. Give the `cd` and name the builder: **implementkit** against this issue when it's installed, otherwise plain "implement the issue in that worktree". For an unattended run, **afkkit** takes it from here to an open PR, and since afkkit calls `start` itself, mention it as `afkkit <n>` from anywhere rather than as something to run from inside the worktree; it adopts the worktree this run just prepared.

**Stop there.** `start` prepares the ground and nothing else. It does not implement, does not launch an agent, and does not commit; naming the next step is routing, not doing it.
