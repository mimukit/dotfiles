---
name: commitkit
description: >-
  Commit this session's changes with Conventional Commits messages derived from the actual diff, then push them to origin. Use when the user asks to commit changes, says "commit this", runs "/commitkit", runs "/commitkit all" to commit every change in the tree, or wants a well-formed commit message written for staged work, even if they don't spell out the format.
license: MIT
allowed-tools: Bash, Read
metadata:
  internal: false
---

# commitkit

Turn the current changes into one or more clean commits with [Conventional Commits](https://www.conventionalcommits.org) messages inferred from the diff itself, not from a guess. The message describes what actually changed, in the imperative mood, with a correct type and scope. In a coding session the default is **multiple commits**, one per feature group or logically related change, never a single catch-all commit.

## When this fires

The user asks to commit ("commit this", "make a commit", "/commitkit", "commit my changes"). A request for the *message only* ("draft a commit message", "what should the message say") takes the [Message-only route](#message-only-route), which never stages, commits, or pushes. A caller that wants the commits without the push says `no-push` ("commit only, do not push"); see [Commit each group](#5-commit-each-group).

This skill is built for AI coding sessions where the user hands off with a bare "commit". In that mode you are expected to work autonomously: stage this session's files yourself, group the work into as many commits as it deserves, commit them, push them, and report back a table of what you created, without stopping to ask at each step.

## Scope

A run commits **this session's changes**, not every change in the tree. One branch or worktree often carries several fixes at once, made by other agents or in other sessions, and a run leaves that work exactly as it found it. Resolve the scope before you group anything, taking the first rule that matches:

1. **`all`** (`/commitkit all`, "commit everything", "commit all changes"). The scope is every change in the tree.
2. **A named scope** ("commit the auth fix", a list of paths). The scope is the changes that match it.
3. **The session set.** The scope is every path you created, edited, deleted, or renamed in this session, by any tool. It includes the files a command you ran changed as part of the work, such as a lockfile from a dependency install or the output of a code generator.
4. **No session set**, because the session is fresh or the work has left your context. Stop, list the changed paths, and ask which to commit. Name `/commitkit all` as the way to take everything.

**A path outside the scope is out of bounds.** Record those paths as the **out-of-scope list**. Never stage one, commit it, restore it, or discard it. A path another session staged stays staged, through the keep-staged set in [Group the work into multiple commits](#4-group-the-work-into-multiple-commits).

**A session path can hold hunks you did not write**, when another session edited the same file. When its stat shows more change than you made, or you know another session works in that file, read its diff. Commit only your own hunks, staged as a patch the way a mixed file is in [Commit each group](#5-commit-each-group). When the hunks overlap and cannot be split, stop and ask.

## Message-only route

A user in a live session wants the message, not the commit. This route reads and prints. The index, the refs, and the remote stay exactly as they were.

1. Record the opening state in one call: `git status --short && git rev-parse HEAD && git diff --cached --binary | git hash-object --stdin && git for-each-ref | git hash-object --stdin`. `hash-object` without `-w` writes nothing.
2. Pick the subject. A non-empty staged set is the subject, so read `git diff --cached`. With nothing staged, the subject is the [Scope](#scope), so read `git diff HEAD -- <scope paths>`, or a pathless `git diff HEAD` under `all`. The read limits in [Read the state](#1-read-the-state) apply.
3. Apply [Decide type and scope from the diff](#2-decide-type-and-scope-from-the-diff) and [Write the message](#3-write-the-message). Write one message for the subject. When the subject plainly spans several concerns, write one message per group and name each group's paths.
4. Print each message in a code block.

The only git commands on this route are reads: `status`, `diff`, `log`, `rev-parse`, `for-each-ref`, and `hash-object` without `-w`.

**Done when** every message is printed and a closing run of the record commands prints the same commit and the same two hashes as the opening run. Hand off in one line: say nothing changed, and name the next move, which is to say "commit" to commit with these messages.

## Draft mode

**Entry condition, and both halves must hold**: the caller names draft mode, and the staged diff arrives in the prompt itself inside `<staged-diff>` tags with no tools available to you. A git tool such as a lazygit custom command drives this mode. It inlines this file, appends the diff and any supporting context, captures your stdout, and writes that text straight into its commit panel. Every word you emit that is not the commit message corrupts the commit.

Draft mode replaces [Scope](#scope), [Read the state](#1-read-the-state), [Group the work into multiple commits](#4-group-the-work-into-multiple-commits), [Commit each group](#5-commit-each-group), and [Hand off](#6-hand-off). [Decide type and scope from the diff](#2-decide-type-and-scope-from-the-diff) and [Write the message](#3-write-the-message) apply unchanged, so the scope stays mandatory and the body stays required.

- **Write exactly one commit message for the whole staged set.** The multiple-commits default does not apply here, because the caller owns the staging and you cannot restage anything.
- **Emit the raw message and nothing else**: the subject line, one blank line, then the body. No preamble, no code fence, no summary table, no hand-off, no next move, no `Co-authored-by`, no tool advertising. The first character of your output is the first character of the subject.
- **Read the whole payload for repo context.** It may carry `git log --oneline` output. Match the style of those subjects, per the repo-convention rule in [Notes](#notes).
- **Expect a `[diff truncated]` marker.** Write the message from the visible part of the diff. Keep the truncation out of the commit.
- **No diff, no output.** If the payload holds no diff, print nothing and stop.

Draft mode outranks the codeblock fallback in [Notes](#notes). A code fence serves a human who copies the message by hand; a commit panel takes the message bare.

## Procedure

### 1. Read the state
Start from the file-level shape of the change, never the full diff, in a single call:

```sh
git status --short && git diff --stat HEAD && git diff --cached --no-renames --name-only   # tree state, one line per file, the staged set
```

**Record the staged set.** The last command lists every path that was staged before you touched anything. Keep that list for the whole run, because a `git add` only ever adds to the index: a path staged earlier rides into the next commit unless you place it on purpose. A path that shows `MM` in `git status --short` is **partially staged**. The user staged some of its hunks and left the rest, so its staged hunks are the content a group takes, and you never re-add the whole path unless the user says so.

**Batch every git call in this skill the same way.** This skill fires at the end of a session, when the context window is at its largest, and each extra Bash call re-pays that whole window as input. Chain commands with `&&` whenever no decision sits between them; spend a separate call only where you must stop and think between two commands.

**Then decide how much diff you actually need, by asking who wrote these changes.**

- **You did, in this same context** (the typical coding-session hand-off). You already know what the change does and, more importantly, *why*, and the why is the part a diff can't tell you: the approach you rejected, the test that caught a bug mid-way, the file you deliberately left alone. Group from the stat and write the body from what you know. Read a diff only for files you didn't touch yourself, or where you genuinely can't recall what landed.
- **You didn't.** The scope is `all` or a named scope that reaches past your own edits, you were dispatched as a subagent, or the work happened far enough back that it's no longer in context. Then the diff is your only source, but take it group by group, never wholesale. Sketch the groups from the stat first, then read each group's diff with `git diff HEAD -- <paths>` and stop once that group's type, scope, and effect are clear. A pathless `git diff HEAD` pulls the whole session's changes into context at once; the per-group read caps each read at the group you're actually writing about.

When in doubt, read. A vague commit message costs more than the tokens it saved. But re-reading code you wrote minutes ago buys nothing: the stat already tells you which files moved, and you already know what you did to them.

**Never read the content of generated files** in either mode, meaning lockfiles (`*.lock`, `package-lock.json`, `pnpm-lock.yaml`, `go.sum`), build output, vendored directories, snapshots, compiled assets. Their stat line carries every bit of signal a commit message can use, and their diffs are the largest in most repos.

- When the user has **delegated committing** (the typical coding-session "commit" / "commit my changes"), you are free to stage the files you need yourself, so `git add` the paths for each logical group as you commit it. You don't have to ask first; grouping and staging is your job here.
- Only pause to ask when intent is genuinely ambiguous, e.g. the tree holds half-finished work, secrets, changes you suspect the user didn't mean to commit, or a file is partially staged and staging its whole path would include deliberately unstaged hunks. Never `git add -A` blindly across unrelated concerns; stage per group instead (see [Group the work into multiple commits](#4-group-the-work-into-multiple-commits)).
- If the user asked for a single specific commit, respect that and don't auto-split.
- If **the scope holds no change**, stop and say so. Name the out-of-scope changes when the tree has some.

**Done when** you hold the resolved [Scope](#scope) with its path list, the changed-path list, the recorded staged set with its partially staged paths marked, and the answer to who wrote the changes.

### 2. Decide type and scope from the diff
Pick the `type` from what the diff *does*, not what files it touches:

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

**`hotfix` is `fix` in a hurry, and the branch decides it, not the severity.** Use `hotfix` when the commit sits on a branch named `hotfix-<slug>`, cut from the base branch to patch it directly. Everything else stays `fix`, however urgent it felt. This keeps the type checkable from the branch name rather than from a judgement about how bad the bug was. `hotfix` is an addition to the [Conventional Commits](https://www.conventionalcommits.org) set, so drop back to `fix` in a repo whose tooling validates types against the standard list; say once that you did.

**Scope** is **mandatory** here. Unlike vanilla Conventional Commits, never omit it. Work out the module or feature group the diff belongs to (a package, module, directory, or feature area) and use that as the scope: `feat(auth): …`. When a change is genuinely global or fits no single area (repo-wide config, tooling, cross-cutting cleanup), use `repo` as the scope: `chore(repo): …`. Add a `!` (or a `BREAKING CHANGE:` footer) when the change breaks existing behavior.

**Done when** every planned commit has exactly one type and one scope.

### 3. Write the message
Format:

```
type(scope): short imperative summary

one-line summary of why the change was made

- reason/change bullet
- reason/change bullet

Reference issues in a footer.
```

The `(scope)` is required, so every message carries one, falling back to `(repo)` for global work.

Rules:
- **Imperative mood**, **all lowercase** subject. Never capitalize the first word or any word in the title (proper nouns and acronyms are the only exceptions), use **no trailing period**, and aim for ≤ 50 characters.
- The summary states the *effect* of the change ("add retry to fetch client"), not the activity ("changes to fetch client").
- **Keep every body line at 72 characters or fewer.** Break a longer bullet into two bullets, or continue it on an indented next line. Commit hooks such as commitlint's `body-max-line-length` reject long lines, and 72 clears the common 72/80/100 limits.
- **A body is required.** Open with a short one-line summary of *why*, then a bullet list capturing the reasons and the concrete changes. Keep it to what a reviewer needs. Don't pad trivial commits, but always include the summary line and at least one bullet.
- Do **not** add `Co-authored-by` or tool advertising unless the user asked for it.

**Done when** every message has a lowercase imperative subject with a scope, a one-line why, at least one bullet, and no body line over 72 characters.

### 4. Group the work into multiple commits
Before committing anything, map the changes to logical groups. Each **feature group or related unit of work** (a feature and its tests, a bugfix, a docs update, a refactor, a config bump) becomes its **own commit**. This is the default, not an exception: a session that touched three concerns should produce three commits, each with its own scope.

Group by *what the change accomplishes*, not by file type or directory. Keep a feature together with the tests and docs that belong to it rather than splitting them across commits. Don't over-fragment either; a single cohesive change is one commit even if it spans several files.

Order the groups so dependencies land first (e.g. a shared helper before the feature that uses it). When a file contains hunks from multiple groups, plan to stage it interactively rather than assigning the whole path to one group.

**Place every path in the recorded staged set.** A pre-staged path inside the [Scope](#scope) joins the group it belongs to. A pre-staged path outside the scope joins no group and stays staged after the run. List those paths as the **keep-staged set**.

**Done when** every in-scope changed path sits in exactly one group or on a stated skip list, every out-of-scope path sits on the out-of-scope list, and every recorded staged path sits in a group or in the keep-staged set.

### 5. Commit each group
With every group and message already planned, stage and commit them all in **one Bash call**, chained with `&&`, and close the chain with the push and the `git status -sb` the hand-off needs. **Before each commit, check that the staged set equals exactly that group's paths**, so the commit cannot take a path that belongs elsewhere:

```sh
git add -- <group 1 paths> && \
test "$(git diff --cached --no-renames --name-only | sort)" = "$(printf '%s\n' <group 1 paths> | sort)" && \
git commit -m "type(scope): summary" -m "why in one line

- reason/change bullet
- reason/change bullet" && \
git add -- <group 2 paths> && \
test "$(git diff --cached --no-renames --name-only | sort)" = "$(printf '%s\n' <group 2 paths> | sort)" && \
git commit -m "type(scope): summary" -m "why in one line

- reason/change bullet" && \
git push -u origin HEAD && git status -sb && \
gh pr view --json number,url,state 2>/dev/null || true
```

Leave a partially staged path out of `git add` and keep it in the check list, so the group takes its staged hunks only. List both sides of a rename in its group, because `--no-renames` prints the old path and the new path.

**Park the staged paths that are not this group's.** When the recorded staged set holds paths outside the current group (keep-staged paths, or paths of a later group), the check fails until they leave the index. Move them aside as a patch, commit the group, and put them back:

```sh
park="$(git rev-parse --git-path commitkit-park.patch)"
git diff --cached --binary --no-renames -- <other staged paths> > "$park" && \
git restore --staged -- <other staged paths> && \
git add -- <group paths> && \
test "$(git diff --cached --no-renames --name-only | sort)" = "$(printf '%s\n' <group paths> | sort)" && \
git commit -m "type(scope): summary" -m "…"; \
git apply --cached "$park"
```

The patch holds the exact staged hunks, so a partially staged file comes back partially staged, and a staged new file or deletion comes back staged. `git commit -- <paths>` is shorter, but it commits the working-tree copy of each path, which pulls the unstaged hunks of a partially staged file into the commit. The `;` before `git apply` restores the parked paths even when the check or the commit fails. Because the `;` also lets a chain run on after a failed commit, run each parked group as its own call and start the next group only after its commit landed. If `git apply --cached` fails, stop and report the patch path, because the parked hunks are in that file.

The `gh pr view` tail tells the hand-off whether this branch already has a pull request. It costs nothing extra, because it rides the same call. An empty result or a `gh` failure means no pull request, and that is a normal outcome rather than an error.

**Push by default when the push is a plain fast-forward to `origin`.** A commit that lives only on this machine is one lost disk away from gone, and publishing it is the move the user makes almost every time. Push when the repo has an `origin` remote and the branch either tracks `origin` or has no upstream at all. The branch name does not gate this; a topic branch and the base branch push the same way.

Hold the push and ask in these cases:

- **The remote rejects it.** Report the rejection and stop. Never reach for `--force` or `--force-with-lease` here; a rejected push means the branch moved on the remote, and rewriting it is gitkit's and prkit's business, not commitkit's.
- **There is no `origin`,** or the branch tracks some other remote. Report the commits and name the push the user would run.

**Skip the push when the user or a calling skill says `no-push`** ("commit only, do not push", "commit, don't push", "don't publish yet"). Drop `git push -u origin HEAD` from the chain, keep `git status -sb`, and say the commits are local. A calling skill that passes `no-push` owns the push: afkkit, for one, publishes the branch once, when prkit opens the PR.

Interactive staging of a mixed file (see [Group the work into multiple commits](#4-group-the-work-into-multiple-commits)) is the one step that can't join the chain. Commit up to that group in one call, handle the split, then chain the rest.

When the user delegated the commit ("commit", "commit my changes"), just do this for every group, with no per-commit confirmation. A request for a message only never reaches this step; it ends on the [Message-only route](#message-only-route). If a commit fails (e.g. a pre-commit hook rejects it), the `&&` chain stops at the failing group and later groups stay uncommitted, so surface the hook output, fix or ask, then resume the chain from that group. Don't retry blindly or bypass hooks with `--no-verify` unless told to.

**Done when** each commit's file list in `git log --stat` equals its group's paths, the staged set left after the run equals the keep-staged set, every out-of-scope path shows the same `git status --short` line as at the start, and the push either ran or has a recorded reason to hold.

### 6. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Close with what changed, where it landed, and the next move.

**What changed.** Print a summary table of the commits you created so the user sees the result at a glance:

| # | commit message | files |
|---|----------------|-------|
| 1 | `feat(auth): add token refresh retry` | `auth/token.ts`, `auth/token.test.ts` |
| 2 | `chore(repo): bump ci node version` | `.github/workflows/ci.yml` |

List each commit's changed/created files in the last column. You already know them, since they're the paths you passed to `git add` for each group, so build the table from that rather than querying git again. If you do need to check, one `git log --stat --oneline -<n>` covers every commit you just made; don't run a separate `git show` per commit. If a commit touches many files, list the key ones and add "+N more". If anything remains uncommitted (intentionally skipped, left for the user, or kept staged on purpose), note it under the table. Name the out-of-scope paths in one line, so the user sees which changes the run left for another session or for `/commitkit all`.

**Where it landed.** Report the branch the commits sit on, and say whether the push happened. The `git status -sb` at the end of the commit chain prints the branch and its upstream in one line; report from that output rather than running it again. When the push did not happen, say so and name the reason, because commits that exist nowhere but this machine are the most useful line in the report.

**Next.** Name one move and stop. Pick it from the state you already read, in this order:

1. **A calling skill passed `no-push`.** Report the commits and return to the caller. The caller owns the next move, so crown nothing.
2. **The push did not happen.** Crown the push and give the command.
3. **The branch already has an open pull request** (the `gh pr view` tail printed one). The commits are on it now, so crown the review move, not a new pull request. Say the pull request updated, give its number and URL, and name the move that fits the reason you committed. After review fixes, that is to reply to the reviewer and re-request review with **mergekit**, otherwise `gh pr comment <number>`. Never crown opening a pull request for a branch that has one.
4. **The pull request is merged or closed.** Say so and crown a new branch for this work with **gitkit**, otherwise `git switch -c <name> <base>`.
5. **The branch has no pull request.** Crown opening one from exactly these commits: **prkit** when it is installed, otherwise `gh pr create`.
6. **The feature clearly is not finished.** Say that and crown the plain action, which is to keep building, then re-run commitkit for the next group.

Don't open a pull request yourself; commitkit's job ends at the push.

**Done when** the table lists every commit, the branch line says whether the push ran, and exactly one next move is named, or the report returns to a calling skill.

## Notes

- **Never** run `git commit --amend`, `git rebase`, `git reset`, or any other history-rewriting command unless the user explicitly asks. A fast-forward push publishes work and is recoverable with a revert; rewriting a published branch is not, which is why the guard sits here and not on the push (see [Commit each group](#5-commit-each-group)).
- If a repo has its own commit convention (a `CONTRIBUTING.md`, a commit template, or an obviously different style in `git log`), follow that over these defaults and say you did.
- No filesystem or shell? Then you can't run `git`. Instead read the diff the user provides and print the finished commit message as a codeblock for them to run themselves.
