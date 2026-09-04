## Mode `start <n>`: make it merge-ready

### 1. Resolve the head

```sh
gh pr view <n> --json headRefName,headRepositoryOwner,isCrossRepository,author,title,body,url
```

A **cross-repository (fork) PR** is read-only from here: you can review and merge it, but you cannot push fixes to the contributor's branch. Say that plainly at setup time rather than letting it surface as a confusing push failure later.

### 2. Get a worktree, adopting first and creating only if needed

**Hand this to gitkit, keyed on the PR's head branch.** The key point, and the reason this step is not "create a worktree": a PR's branch very often *already has one*, because the branch was implemented in a worktree on this same machine, and that worktree is still sitting there. Git allows a branch to be checked out in exactly one worktree, so creating a second one for the review does not merely duplicate work, it hard-fails:

```
fatal: 'feature-x' is already used by worktree at '.../wt-a'
```

So: resolve the head branch, look it up, and **reuse the worktree that already holds it**. Create one only when the branch has none.

- **Same-repo PR.** Fetch the head branch (`git fetch origin <head>:<head>` or `git fetch origin` plus a local checkout), then ask gitkit for that branch's worktree. Pushes from it go back to the PR.
- **Fork PR.** There is no local branch yet, so one must be invented: `git fetch origin "pull/<n>/head:pr-<n>-<slug>"`, where `<slug>` is the head branch name kebab-cased and capped at roughly 40 characters. Then the worktree is created on *that* branch, and takes its name.
- **Already have one.** Adopt it and say so. Re-running `start` is a normal thing a reviewer does; it must never error, and must never blow away work in progress. If the adopted worktree is dirty, **report what's uncommitted before doing anything else** and let the reviewer decide whether to continue, because you are standing in someone's live workspace, possibly mid-change, not a scratch checkout.

The worktree lands wherever gitkit's convention puts it, outside the repository rather than in a `.worktrees/` directory inside it. An in-repo worktree gets swept into docker build contexts, bind mounts, and file watchers, and every one of those failures surfaces far from its cause. Nothing here needs a `.git/info/exclude` entry.

### 3. Sync with the base branch

Bring `origin/<base>` into the PR branch *before* the human reviews, so they review what will actually land:

```sh
git fetch origin
git rev-list --left-right --count origin/<base>...HEAD    # "<behind>\t<ahead>"; left > 0 means behind
```

If behind, **hand the sync to gitkit**, which owns the rebase-versus-merge rule in full. What mergekit owns is the *when*: that the sync happens before a human reads the diff, and that nothing leaves this machine without their OK.

Two things follow from gitkit's rule that matter specifically here. A PR branch is published, so the sync is in the **preview-and-confirm** class: one prompt covering the rebase and its `--force-with-lease` push, never a silent rewrite of a branch a reviewer may already be looking at. And this is the one place the merge exception's trigger actually fires: [the review pack](#5-print-the-review-pack) already queries unresolved review threads, so **feed that count into the preview**, because a rebase marks every one of them outdated, and the reviewer is about to spend their attention on exactly those threads. Name the number, still recommend the rebase, and let them take the merge if the threads are worth more than the history.

**On conflict:** stop and surface it. List the conflicted files (`git diff --name-only --diff-filter=U`), propose a resolution for each, and confirm before writing. Then, before pushing, **run the repo's own test and build gate**, because a conflict resolution is a code change, and it can break something CI passed on five minutes ago. Push the sync only after the gate is green and the human has OK'd it, so the PR itself becomes mergeable on GitHub. On a fork PR you cannot push; say so, and keep the sync local for review purposes only.

### 4. Set the project up

Detect the manifest (`package.json`, `pyproject.toml`, `go.mod`, `Gemfile`, `Cargo.toml`, …) and run the install the repo actually uses: the lockfile tells you which package manager, the scripts tell you the dev command. Prefer a project-local run or dev skill when one exists. **Never invent a command**: if you cannot determine how to start the app, say so and ask, rather than guessing at a `dev` script that doesn't exist. Copy `.env.example` to `.env` only if that is the repo's documented setup and the file is absent.

### 5. Print the review pack

Everything the reviewer needs, assembled once so they don't go hunting:

- PR title, number, author, URL, and the body's summary.
- The linked issue and its acceptance criteria, when the PR references one.
- The commits (`git log origin/<base>..HEAD --oneline`) and the file-level shape of the diff (`--stat`).
- The QA plan, if the repo has one for this change, and any proof artifacts.
- **Unresolved review threads with `file:line` and the comment text**, bot or human. This is the highest-value part of the pack: it is what the reviewer would otherwise re-derive by hand.
- Any follow-up nits the PR body itself records.
- CI status per check, and whether the branch is now in sync.

**Name what is missing.** "No QA plan in this repo's conventional location" is information; printing nothing where a QA plan would go is not.

### 6. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Report whether the worktree was adopted or created, and whether a sync was pushed (and if so, whether it rebased or took the merge exception, and how many threads it outdated). Nothing else here mutates anything.

**Where it landed.** Two lines: the worktree path, and the single command that starts the app.

**Next.** The reviewer reads, runs, and forms an opinion; then `close <n>` executes whichever verdict they reach, whether a merge or a fix round. Say both halves, so it's clear merging isn't the assumed outcome.

Then stop, because the human reviews and tests. mergekit does not judge the code, and does not proceed to `close` on its own.
