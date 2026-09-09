## Mode `start <n>`: prepare the review workspace

**`<n>` is a PR number, always.** mergekit starts from an open pull request, so read the bare number in `start 34`, `start #34`, or "pull 34 down" as PR 34. Never read it as an issue number, even when a same-numbered issue exists. If the user means the issue, they say so, and that run belongs to issuekit's `start`.

`start` prepares the workspace and stops. It creates or adopts the worktree, gets the project running, and prints the review pack. **It never syncs the branch and never pushes.** The reviewer runs **gitkit `sync`** inside the worktree when they choose to, because a sync rewrites a published branch and outdates review threads, and that call belongs to the human who is about to read them.

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

### 3. Measure the base-branch gap and report it

Fetch, then measure how far the branch has drifted:

```sh
git fetch origin
git rev-list --left-right --count origin/<base>...HEAD    # "<behind>\t<ahead>"; left > 0 means behind
```

**Report the two numbers and stop there.** Do not rebase, do not merge the base in, do not push. The reviewer decides whether the drift matters, and runs **gitkit `sync`** inside the worktree when it does.

The reason the sync waits: a sync rewrites a published branch and marks every unresolved review thread outdated. [The review pack](#5-print-the-review-pack) prints that thread count beside the behind count, so the reviewer weighs both before they act. Without gitkit, the plain fallback is a rebase onto the base followed by `git push --force-with-lease`, and the reviewer runs it themselves.

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
- CI status per check, and the behind/ahead counts against `origin/<base>`.

**Name what is missing.** "No QA plan in this repo's conventional location" is information; printing nothing where a QA plan would go is not.

### 6. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Report whether the worktree was adopted or created. State that no sync ran and nothing was pushed. Nothing else here mutates anything.

**Where it landed.** Two lines: the worktree path, and the single command that starts the app.

**Next.** The reviewer reads, runs, and forms an opinion. When the branch is behind, name **gitkit `sync`** inside the worktree as the first move, and give the behind count. Then `close <n>` executes whichever verdict they reach, whether a merge or a fix round. Say both halves, so it's clear merging isn't the assumed outcome.

Then stop, because the human reviews and tests. mergekit does not judge the code, and does not proceed to `close` on its own.
