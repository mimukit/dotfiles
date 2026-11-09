## Mode `start <n>`: prepare the review workspace

**`<n>` is a PR number, always.** mergekit starts from an open pull request, so read the bare number in `start 34`, `start #34`, or "pull 34 down" as PR 34. Never read it as an issue number, even when a same-numbered issue exists. If the user means the issue, they say so, and that run belongs to issuekit's `start`.

`start` prepares the workspace and stops. It creates or adopts the worktree, gets the project running, and prints the review pack. **It syncs and pushes only when the human asked for it in the same request**: "start #34 and sync". Otherwise the reviewer runs **gitkit `sync`** inside the worktree when they choose to, because a sync rewrites a published branch and outdates review threads, and that call belongs to the human who is about to read them.

### 1. Resolve the head

```sh
gh pr view <n> --json headRefName,headRefOid,headRepositoryOwner,isCrossRepository,author,title,body,url
```

A **cross-repository (fork) PR** is read-only from here: you can review and merge it, but you cannot push fixes to the contributor's branch. Say that plainly at setup time rather than letting it surface as a confusing push failure later. A fork PR also refuses the "and sync" ask, because the sync ends in a push: say so here, and carry on with a plain `start`.

Record `headRefOid`. It is the **reviewed head**, the commit the reviewer is about to judge, and [`close`](./close.md#merge-path) merges that commit and no other. Ends when the head branch, the reviewed head SHA, and the fork status are known.

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

Ends when the worktree path is known, it sits at the reviewed head, and its dirty state is reported.

### 3. Measure the base-branch gap and report it

Fetch, then measure how far the branch has drifted:

```sh
git fetch origin
git rev-list --left-right --count origin/<base>...HEAD    # "<behind>\t<ahead>"; left > 0 means behind
```

**Report the two numbers and stop there**, unless the request asked for the sync. Do not rebase, do not merge the base in, do not push. The reviewer decides whether the drift matters, and runs **gitkit `sync`** inside the worktree when it does.

The reason the sync waits: a sync rewrites a published branch and marks every unresolved review thread outdated. [The review pack](#5-print-the-review-pack) prints that thread count beside the behind count, so the reviewer weighs both before they act. Without gitkit, the plain fallback is a rebase onto the base followed by `git push --force-with-lease`, and the reviewer runs it themselves.

**"Start #34 and sync" is that decision, made up front.** The ask is the consent to the rebase and the `--force-with-lease` push, as it is for gitkit `sync` itself. Hand the sync to **gitkit** in the worktree; it resolves to a rebase, stops on a dirty tree or a conflict that needs a ruling, and reports the review threads the push outdated. Run it here, before [Set the project up](#4-set-the-project-up), so the install matches the synced lockfile. Without gitkit, rebase onto the base and push with `--force-with-lease`. A behind count of `0` needs no sync; say so. A stopped sync leaves the branch where it was: report why, and carry on unsynced.

This step ends when both numbers are reported, and, on a sync request, when the sync has pushed or stopped with its reason.

### 4. Set the project up

**Hand the setup to gitkit `prepare`** in the worktree. It runs the repo's declared worktree setup (install, untracked files, the worktree's own database, seed), or only the lockfile install when the repo declares none, and it skips an adopted worktree whose watched files have not changed. A failed setup stops this step: report the command, the exit code, and the output tail gitkit returns. Without gitkit, run the `setup:` block of the repo's `## Worktree setup` section from the worktree root, otherwise the install the lockfile implies.

Then start the app. The scripts tell you the dev command; prefer a project-local run or dev skill when one exists. **Never invent a command**: if you cannot determine how to start the app, say so and ask, rather than guessing at a `dev` script that doesn't exist. Copy `.env.example` to `.env` only if that is the repo's documented setup, the file is absent, and the declared setup did not already write it.

Ends on an observed result. For a server, that is the app answering on its port. For anything else, it is the project's own observable: a CLI that prints its `--help`, a library whose build passes. Otherwise it ends on a reported reason the project cannot start, with the command and its output.

### 5. Print the review pack

Everything the reviewer needs, assembled once so they don't go hunting:

- PR title, number, author, URL, and the body's summary.
- The linked issue and its acceptance criteria, when the PR references one.
- The commits (`git log origin/<base>..HEAD --oneline`) and the file-level shape of the diff (`--stat`).
- The QA plan, if the repo has one for this change, and any proof artifacts.
- **Unresolved review threads with `file:line` and the comment text**, bot or human. This is the highest-value part of the pack: it is what the reviewer would otherwise re-derive by hand.
- Any follow-up nits the PR body itself records.
- CI status per check, and the behind/ahead counts against `origin/<base>`.

**Name what is missing.** "No QA plan in this repo's conventional location" is information; printing nothing where a QA plan would go is not. Ends when every item above is printed or named as missing, and the pack shows the reviewed head SHA.

### 6. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Report whether the worktree was adopted or created. Report what gitkit `prepare` ran: the declared setup, an update and the paths that triggered it, the lockfile install only, or nothing. Report the sync: not asked, or asked and its result, with the commits rebased and the review threads the push outdated. When no sync ran, state that nothing was pushed.

**Where it landed.** Give the single command that starts the app. Then print gitkit's workspace block as the last lines of the reply, after **Next**, with `for: PR #<n>` and the PR's base branch. Without gitkit, print the same block:

```
Workspace ready
- repo: <absolute path of the main checkout>
- worktree: <absolute worktree path>
- branch: <PR head branch>
- base: <PR base branch>
- state: created | adopted
- for: PR #<n>
```

The block starts nothing. A host that can open a session bound to a worktree reads it; the reviewer decides what happens there.

**Next.** The reviewer reads, runs, and forms an opinion. When the branch is still behind, name **gitkit `sync`** inside the worktree as the first move, and give the behind count. Then `close <n>` executes whichever verdict they reach, whether a merge or a fix round. Say both halves, so it's clear merging isn't the assumed outcome.

Then stop, because the human reviews and tests. mergekit does not judge the code, and does not proceed to `close` on its own.
