# Starting a hotfix: `gitkit hotfix`

Reference for gitkit's [`hotfix`](./SKILL.md#hotfix) mode. Read it when a run starts a hotfix, and when a merged hotfix needs to reach another branch.

A hotfix is an urgent fix or a quick change that goes straight to the branch production deploys from. It skips the issue tracker: no issue, no `ready` label, no grill. It keeps the pull request, because CI and a reviewed **Rollback** line are what make a fast change safe. gitkit prepares the ground and stops. Writing the change, committing it, and opening the pull request belong to other skills.

The mode has two parts. **Start** runs at the beginning of every hotfix. **Backport** runs after the merge, and only when the hotfix base is not the branch everything else is built on.

## The hotfix flow

A project's production path is its own, so the hotfix base is the project's to declare, and gitkit never guesses past the evidence. Resolve the flow in this order, and stop at the first answer.

### 1. The declaration

A repository declares its hotfix flow in a `## Hotfix flow` section of its agent-guide file: `AGENTS.md` at the repository root, else `CLAUDE.md`. Read it from `origin/<default branch>` with `git show`, because the worktree does not exist yet and a local checkout may be stale.

Each label is a line of its own, followed by one fenced block:

- **`base:`** (required). The one branch production deploys from. The hotfix is cut from it, and its pull request targets it.
- **`backport:`** (optional). One branch per line. After the hotfix merges, its commits go onto each of these too, so the next release from them does not undo the fix.
- **`ship:`** (optional). How a merged change on `base` reaches production, in a sentence or a command. gitkit reports it in the hand-off and never runs it.

### 2. The evidence

With no declaration, read the repository for a deploy branch. All of these are read-only:

- A workflow under `.github/workflows/` whose file name or job name says `deploy`, `release`, or `production`, triggered by `on: push: branches:`. The branches it lists are deploy branches.
- `git config --get gitflow.branch.master`, when git-flow is set up. A git-flow repository also backports to `gitflow.branch.develop`.

**A deploy branch that is the default branch confirms the default.** A deploy branch that differs from it is a candidate: name the file or the setting that points at it, ask once whether to cut the hotfix from it, and print [the template](#the-template) so the answer can be written down. A workflow that deploys on a schedule or by hand, from the default branch, is a batch deploy: record that for the hand-off.

### 3. The default

With no declaration and no evidence, the base is the default branch from [the base ref ladder](./SKILL.md#the-base-ref), there is no backport, and the change reaches production with the next deploy of that branch. Say so in the hand-off, so nobody assumes a merge is a deploy.

### The template

Print this when the flow came from evidence or from the default, adapted to what the run found:

~~~markdown
## Hotfix flow

base:
```text
production
```

backport:
```text
main
```

ship:
```text
Merging to production starts .github/workflows/deploy.yml.
```
~~~

`base:` is the branch production deploys from. Leave out `backport:` when `base:` is also the branch new work starts from.

## Start

1. **Resolve the flow.** Run [The hotfix flow](#the-hotfix-flow) after `git -C "$REPO" fetch origin --prune`. Confirm `origin/$BASE` exists. Ends with a base, a backport list that may be empty, and a ship line.
2. **Name the branch.** Take the slug from the symptom for a fix, or from the change for a quick change, as [Branch naming](./SKILL.md#branch-naming) states. Look the branch up through `git worktree list --porcelain` and `git branch --list`. An existing `hotfix-*` branch for the same symptom is adopted, not duplicated. Ends with a free name, or a branch to adopt.
3. **Create or adopt the worktree.** Run [Create, or adopt](./SKILL.md#create-or-adopt) with `origin/$BASE` as the base, including its records. Then record the pull request base: `git -C "$REPO" config "branch.$BRANCH.gh-merge-base" "$BASE"`. `gh pr create` reads this key, and [the base ref ladder](./SKILL.md#the-base-ref) returns it for this branch. Ends when the worktree is on `$BRANCH` and the key is set.
4. **Bring an existing change along.** When the main checkout is on `$BASE` with uncommitted changes, the hotfix may already be written there. Show `git -C "$REPO" status --short` and ask whether to move it. On a yes, run `git -C "$REPO" stash push --include-untracked -m "gitkit hotfix $BRANCH"`, then `git -C "$WT" stash pop`. The stash is shared across worktrees, so the change moves and the main checkout returns to a clean `$BASE`. A pop that conflicts keeps the stash entry: report it and stop. Ends when the change is in the worktree, or there was none to move.
5. **Prepare.** Run [`prepare`](./prepare.md) on the worktree. Ends with the setup's exit code.

### Hand off

Report the branch, its base, whether the worktree was created or adopted, whether a change moved from the main checkout, and the prepare result. State where the flow came from: the declaration, the evidence (name the file), or the default. Print the template when the flow did not come from a declaration.

Say how the change reaches production. Use the `ship:` line, the batch deploy the evidence found, or "with the next deploy of `$BASE`". When `backport:` names branches, say that the fix must reach them after the merge.

Next, write the change with **implementkit**, otherwise by hand in the worktree. When the change moved from the main checkout, the next move is **commitkit** instead, otherwise `git commit`. Then open the pull request with **prkit**, otherwise `gh pr create`, which targets `$BASE` through the key. End the reply with [the workspace block](./SKILL.md#the-workspace-block), with `base: $BASE` and `for: none`.

## Backport

Run this after a hotfix pull request merges into a base that has a backport list. It moves the merged commits onto each backport branch through a pull request, never by a direct push.

1. **Find the merged commits.** Run `gh pr view <n> --json state,mergeCommit,commits`. The state must be `MERGED`. Count the parents of `mergeCommit` with `git rev-list --parents -n 1 <sha>`, and pick the list by the merge method:
   - **Two parents: a merge commit.** One pick, `<sha>` with `-m 1`.
   - **One parent and one PR commit: a squash or a one-commit rebase.** One pick, `<sha>`.
   - **One parent and N PR commits: a squash or a rebase.** Compare the subject of `<sha>~1` with the headline of the PR's second-to-last commit. A match is a rebase: take `git rev-list --reverse "<sha>~N..<sha>"`. Anything else is a squash: take `<sha>` alone.

   Ends with an ordered SHA list on `origin/$BASE`, and the `-m 1` flag when the merge was a merge commit.
2. **Cut one branch per target.** Name it `hotfix-<slug>-to-<target>`, with the target's slashes flattened to dashes. Run [Create, or adopt](./SKILL.md#create-or-adopt) from `origin/<target>`, and set `branch.<name>.gh-merge-base` to the target. Ends when every target has its worktree.
3. **Replay the commits.** Run `git -C "$WT" -c rerere.enabled=true cherry-pick -x <sha>…` in order, with `-m 1` for a merge commit. This replays commits that review already passed and writes no change of its own. Resolve each conflict by [Conflicts](./SKILL.md#conflicts). A commit that is already on the target leaves an empty pick: skip it with `git cherry-pick --skip` and name it. Ends when every commit is applied or skipped.
4. **Prove it.** Run [`prepare`](./prepare.md), then the repository's test and build gate in the worktree. A failure stops this target and is reported with its output. Ends with a pass or a stop per target.

### Hand off

Report each target with its branch, the commits applied and skipped, each resolved conflict, and the gate result. Name each target that stopped, and why.

Next, push each passing branch and open its pull request with **prkit**, otherwise `git push -u origin <branch>` and `gh pr create`. Both read the target from the key. When no target passed, fix the first stop and run the backport again.
