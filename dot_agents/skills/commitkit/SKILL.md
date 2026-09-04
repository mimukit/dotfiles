---
name: commitkit
description: >-
  Create a git commit with a Conventional Commits message derived from the actual diff, then push it to origin. Use when the user asks to commit changes, says "commit this", runs "/commitkit", or wants a well-formed commit message written for staged work, even if they don't spell out the format.
license: MIT
allowed-tools: Bash, Read
metadata:
  internal: false
---

# commitkit

Turn the current changes into one or more clean commits with [Conventional Commits](https://www.conventionalcommits.org) messages inferred from the diff itself, not from a guess. The message describes what actually changed, in the imperative mood, with a correct type and scope. In a coding session the default is **multiple commits**, one per feature group or logically related change, never a single catch-all commit.

## When this fires

The user asks to commit ("commit this", "make a commit", "/commitkit", "commit my changes"). If they only want a *message drafted* (not committed), do everything except the final `git commit`.

This skill is built for AI coding sessions where the user hands off with a bare "commit". In that mode you are expected to work autonomously: stage the right files yourself, group the work into as many commits as it deserves, commit them, push them, and report back a table of what you created, without stopping to ask at each step.

## Draft mode

**Entry condition, and both halves must hold**: the caller names draft mode, and the staged diff arrives in the prompt itself inside `<staged-diff>` tags with no tools available to you. A git tool such as a lazygit custom command drives this mode. It inlines this file, appends the diff and any supporting context, captures your stdout, and writes that text straight into its commit panel. Every word you emit that is not the commit message corrupts the commit.

Draft mode replaces [Read the state](#1-read-the-state), [Group the work into multiple commits](#4-group-the-work-into-multiple-commits), [Commit each group](#5-commit-each-group), and [Hand off](#6-hand-off). [Decide type and scope from the diff](#2-decide-type-and-scope-from-the-diff) and [Write the message](#3-write-the-message) apply unchanged, so the scope stays mandatory and the body stays required.

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
git status --short && git diff --stat HEAD   # tree state + one line per file, one call
```

**Batch every git call in this skill the same way.** This skill fires at the end of a session, when the context window is at its largest, and each extra Bash call re-pays that whole window as input. Chain commands with `&&` whenever no decision sits between them; spend a separate call only where you must stop and think between two commands.

**Then decide how much diff you actually need, by asking who wrote these changes.**

- **You did, in this same context** (the typical coding-session hand-off). You already know what the change does and, more importantly, *why*, and the why is the part a diff can't tell you: the approach you rejected, the test that caught a bug mid-way, the file you deliberately left alone. Group from the stat and write the body from what you know. Read a diff only for files you didn't touch yourself, or where you genuinely can't recall what landed.
- **You didn't.** You were dispatched as a subagent, the session is fresh, the changes are the user's own edits, or the work happened far enough back that it's no longer in context. Then the diff is your only source, but take it group by group, never wholesale. Sketch the groups from the stat first, then read each group's diff with `git diff HEAD -- <paths>` and stop once that group's type, scope, and effect are clear. A pathless `git diff HEAD` pulls the whole session's changes into context at once; the per-group read caps each read at the group you're actually writing about.

When in doubt, read. A vague commit message costs more than the tokens it saved. But re-reading code you wrote minutes ago buys nothing: the stat already tells you which files moved, and you already know what you did to them.

**Never read the content of generated files** in either mode, meaning lockfiles (`*.lock`, `package-lock.json`, `pnpm-lock.yaml`, `go.sum`), build output, vendored directories, snapshots, compiled assets. Their stat line carries every bit of signal a commit message can use, and their diffs are the largest in most repos.

- When the user has **delegated committing** (the typical coding-session "commit" / "commit my changes"), you are free to stage the files you need yourself, so `git add` the paths for each logical group as you commit it. You don't have to ask first; grouping and staging is your job here.
- Only pause to ask when intent is genuinely ambiguous, e.g. the tree holds half-finished work, secrets, changes you suspect the user didn't mean to commit, or a file is partially staged and staging its whole path would include deliberately unstaged hunks. Never `git add -A` blindly across unrelated concerns; stage per group instead (see [Group the work into multiple commits](#4-group-the-work-into-multiple-commits)).
- If the user asked only for a *message* or a single specific commit, respect that and don't auto-split.
- If **nothing has changed at all**, stop and say so.

### 2. Decide type and scope from the diff
Pick the `type` from what the diff *does*, not what files it touches:

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

**Scope** is **mandatory** here. Unlike vanilla Conventional Commits, never omit it. Work out the module or feature group the diff belongs to (a package, module, directory, or feature area) and use that as the scope: `feat(auth): …`. When a change is genuinely global or fits no single area (repo-wide config, tooling, cross-cutting cleanup), use `repo` as the scope: `chore(repo): …`. Add a `!` (or a `BREAKING CHANGE:` footer) when the change breaks existing behavior.

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

### 4. Group the work into multiple commits
Before committing anything, map the changes to logical groups. Each **feature group or related unit of work** (a feature and its tests, a bugfix, a docs update, a refactor, a config bump) becomes its **own commit**. This is the default, not an exception: a session that touched three concerns should produce three commits, each with its own scope.

Group by *what the change accomplishes*, not by file type or directory. Keep a feature together with the tests and docs that belong to it rather than splitting them across commits. Don't over-fragment either; a single cohesive change is one commit even if it spans several files.

Order the groups so dependencies land first (e.g. a shared helper before the feature that uses it). When a file contains hunks from multiple groups, plan to stage it interactively rather than assigning the whole path to one group.

### 5. Commit each group
With every group and message already planned, stage and commit them all in **one Bash call**, chained with `&&`, and close the chain with the push and the `git status -sb` the hand-off needs:

```sh
git add <group 1 paths> && git commit -m "type(scope): summary" -m "why in one line

- reason/change bullet
- reason/change bullet" && \
git add <group 2 paths> && git commit -m "type(scope): summary" -m "why in one line

- reason/change bullet" && \
git push -u origin HEAD && git status -sb
```

**Push by default when the push is a plain fast-forward to `origin`.** A commit that lives only on this machine is one lost disk away from gone, and publishing it is the move the user makes almost every time. Push when the repo has an `origin` remote and the branch either tracks `origin` or has no upstream at all. The branch name does not gate this; a topic branch and the base branch push the same way.

Hold the push and ask in these cases:

- **The remote rejects it.** Report the rejection and stop. Never reach for `--force` or `--force-with-lease` here; a rejected push means the branch moved on the remote, and rewriting it is gitkit's and prkit's business, not commitkit's.
- **There is no `origin`,** or the branch tracks some other remote. Report the commits and name the push the user would run.
- **The user asked you not to push,** with "commit, don't push", "don't publish yet", or a request for a message only. Honor that and say the commits are local.

Interactive staging of a mixed file (see [Group the work into multiple commits](#4-group-the-work-into-multiple-commits)) is the one step that can't join the chain. Commit up to that group in one call, handle the split, then chain the rest.

When the user delegated the commit ("commit", "commit my changes"), just do this for every group, with no per-commit confirmation. Only show messages for approval first if the user asked you to draft rather than commit. If a commit fails (e.g. a pre-commit hook rejects it), the `&&` chain stops at the failing group and later groups stay uncommitted, so surface the hook output, fix or ask, then resume the chain from that group. Don't retry blindly or bypass hooks with `--no-verify` unless told to.

### 6. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

Close with what changed, where it landed, and the next move.

**What changed.** Print a summary table of the commits you created so the user sees the result at a glance:

| # | commit message | files |
|---|----------------|-------|
| 1 | `feat(auth): add token refresh retry` | `auth/token.ts`, `auth/token.test.ts` |
| 2 | `chore(repo): bump ci node version` | `.github/workflows/ci.yml` |

List each commit's changed/created files in the last column. You already know them, since they're the paths you passed to `git add` for each group, so build the table from that rather than querying git again. If you do need to check, one `git log --stat --oneline -<n>` covers every commit you just made; don't run a separate `git show` per commit. If a commit touches many files, list the key ones and add "+N more". If anything remains uncommitted (intentionally skipped or left for the user), note it under the table.

**Where it landed.** Report the branch the commits sit on, and say whether the push happened. The `git status -sb` at the end of the commit chain prints the branch and its upstream in one line; report from that output rather than running it again. When the push did not happen, say so and name the reason, because commits that exist nowhere but this machine are the most useful line in the report.

**Next.** Name one move and stop. The commits are pushed, so the default is to open a pull request from exactly these commits: **prkit** when it's installed, otherwise `gh pr create`. When the push did not happen, crown the push instead and give the command. When the feature clearly isn't finished, say that and name the plain action, which is to keep building, then re-run commitkit for the next group. Don't open a pull request yourself; commitkit's job ends at the push.

## Notes

- **Never** run `git commit --amend`, `git rebase`, `git reset`, or any other history-rewriting command unless the user explicitly asks. A fast-forward push publishes work and is recoverable with a revert; rewriting a published branch is not, which is why the guard sits here and not on the push (see [Commit each group](#5-commit-each-group)).
- If a repo has its own commit convention (a `CONTRIBUTING.md`, a commit template, or an obviously different style in `git log`), follow that over these defaults and say you did.
- No filesystem or shell? Then you can't run `git`. Instead read the diff the user provides and print the finished commit message as a codeblock for them to run themselves.
