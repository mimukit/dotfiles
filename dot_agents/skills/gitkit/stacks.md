# Stacked branches: the `gh stack` surface

Reference for gitkit's [Stacked branches](./SKILL.md#stacked-branches) section. Read this only when a run actually touches a stack; nothing else in gitkit depends on it.

A **stack** is a chain of branches in one repository where each branch targets the one below it and the bottom targets trunk. Opening a pull request per layer means each one reviews as its own small diff, and merging any of them merges every unmerged layer below it, bottom-up, with the layers above rebased automatically.

## Preflight

```sh
gh --version                         # 2.94.0 or newer
git --version                        # 2.20 or newer
gh extension list | grep gh-stack    # extension installed?
```

- **Missing extension** → `gh extension install github/gh-stack`. Say the line rather than working around it.
- **`gh` older than 2.94.0** → the stack commands need 2.90.0, and the issue-dependency flags a caller may pair with them need 2.94.0. Treat 2.94.0 as the floor, and when the version is below it say which half is unavailable rather than refusing outright.
- **A fork** → stop. All branches in a stack must live in **one repository**; cross-fork stacks are not supported. Say this at setup, not when a push fails.
- **A repo requiring signed commits** → say that a server-side rebase produces **unsigned** commits, and rebase locally with `gh stack rebase` instead of letting GitHub do it.

## The commands gitkit runs

| command | does |
|---|---|
| `gh stack init [-b <trunk>]` | start a stack on the current branch |
| `gh stack add <branch>` | add a layer on top of the current one |
| `gh stack view [--json]` | layers in order, with their pull requests and recent commits |
| `gh stack link [--base <trunk>]` | adopt branches or pull requests that already exist into a stack |
| `gh stack rebase [--upstack\|--downstack]` | cascading restack, each layer onto the one below |
| `gh stack sync [--prune]` | fetch, rebase, push, and reconcile pull request state in one call |
| `gh stack unstack [--local]` | detach the stack; `--local` drops local tracking only |

**Add a layer for work that depends on a branch still in review:**

```sh
gh stack checkout <parent-branch>     # or start from the branch already checked out
gh stack add <new-branch>
```

Then hand the new branch to gitkit's [create-or-adopt](./SKILL.md#create-or-adopt) step for its own worktree, exactly as any other branch. The layer's base is the parent branch, which is the [one stated exception](./SKILL.md#the-base-ref) to the sibling-branch ban.

**Keep every lower layer on the remote while a layer above it has an open pull request.** A lower layer is the base of the pull request above it, so `git push origin --delete` on that branch closes the pull request, and GitHub then refuses both `gh pr reopen` and `gh pr edit --base` until the branch is pushed back. The [clean sweep](./clean.md) holds such a branch back for this reason; check with `gh pr list --base "$BRANCH" --state open` before any manual delete.

**Restack after something below changes:**

```sh
gh stack rebase --upstack              # replay every layer above the current one
```

Surface a conflict the way gitkit surfaces any other: list the conflicted files with `git diff --name-only --diff-filter=U`, propose a resolution per file, confirm before writing, and run the repo's test gate afterward, because a conflict resolution is a code change.

**Inspect:**

```sh
gh stack view --json
```

Render it bottom layer first, so the reading order matches the merge order.

## Commands gitkit does not run

- **`gh stack submit`** creates a pull request per layer. gitkit never opens anything; a pull-request-authoring skill owns this.
- **`gh stack merge`** merges the whole stack. gitkit never merges, and the cascade needs a confirmation naming every pull request it will land; a merge skill owns this.
- **`gh stack up`, `down`, `switch`, `top`, `bottom`** navigate layers inside one checkout. This collection gives [each layer its own worktree](./SKILL.md#one-worktree-per-layer), so these would move a branch another worktree already holds.
- **`gh stack modify`** restructures a stack interactively: drop, fold, insert, reorder, rename. **It is a terminal UI, so no agent can drive it.** Print the command and let the human run it:

  ```sh
  gh stack modify
  ```

  Before they run it, the working tree must be clean, no rebase may be in progress, and the history must be linear.

## Degradation: no extension, no problem

The extension automates the branching and the base refs. Neither is magic, so a stack is reproducible with plain git plus one flag:

```sh
git switch -c <new-branch> <parent-branch>    # the layer
gh pr create --base <parent-branch>           # the pull request that targets it
```

Say what is lost rather than implying parity: GitHub renders no stack map, restacking after a change below is manual (`git rebase --onto`), and merging is one pull request at a time in bottom-up order rather than one cascade.

**With no `gh` at all**, the plain-git half still works, so the branch topology is correct and only the pull requests wait. Report that, and never claim a stack exists on GitHub that you could not create.
