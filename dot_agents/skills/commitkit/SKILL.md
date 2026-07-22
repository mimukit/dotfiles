---
name: commitkit
description: >-
  Create a git commit with a Conventional Commits message derived from the actual diff. Use when the user asks to commit changes, says "commit this", runs "/commit", or wants a well-formed commit message written for staged work — even if they don't spell out the format.
license: MIT
allowed-tools: Bash, Read
metadata:
  internal: false
---

# commitkit

Turn the current changes into one or more clean commits with [Conventional Commits](https://www.conventionalcommits.org) messages inferred from the diff itself — not from a guess. The message describes what actually changed, in the imperative mood, with a correct type and scope. In a coding session the default is **multiple commits**, one per feature group or logically related change — not a single catch-all commit.

## When this fires

The user asks to commit ("commit this", "make a commit", "/commit", "commit my changes"). If they only want a *message drafted* (not committed), do everything except the final `git commit`.

This skill is built for AI coding sessions where the user hands off with a bare "commit". In that mode you are expected to work autonomously: stage the right files yourself, group the work into as many commits as it deserves, commit them, and report back a table of what you created — without stopping to ask at each step.

## Procedure

### 1. Read the state
Run these together and read the output before deciding anything:

```sh
git status --short
git diff --staged
git diff            # unstaged, for context
```

- When the user has **delegated committing** (the typical coding-session "commit" / "commit my changes"), you are free to stage the files you need yourself — `git add` the paths for each logical group as you commit it. You don't have to ask first; grouping and staging is your job here.
- Only pause to ask when intent is genuinely ambiguous — e.g. the tree holds half-finished work, secrets, or changes you suspect the user didn't mean to commit. Never `git add -A` blindly across unrelated concerns; stage per group instead (see [Group the work into multiple commits](#4-group-the-work-into-multiple-commits)).
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

**Scope** is **mandatory** here — unlike vanilla Conventional Commits, never omit it. Work out the module or feature group the diff belongs to (a package, module, directory, or feature area) and use that as the scope: `feat(auth): …`. When a change is genuinely global or fits no single area (repo-wide config, tooling, cross-cutting cleanup), use `repo` as the scope: `chore(repo): …`. Add a `!` (or a `BREAKING CHANGE:` footer) when the change breaks existing behavior.

### 3. Write the message
Format:

```
type(scope): short imperative summary

one-line summary of why the change was made

- reason/change bullet
- reason/change bullet

Reference issues in a footer.
```

The `(scope)` is required — every message carries one, falling back to `(repo)` for global work.

Rules:
- **Imperative mood**, **all lowercase** subject — never capitalize the first word or any word in the title (proper nouns and acronyms are the only exceptions), **no trailing period**, aim for ≤ 50 characters.
- The summary states the *effect* of the change ("add retry to fetch client"), not the activity ("changes to fetch client").
- **A body is required.** Open with a short one-line summary of *why*, then a bullet list capturing the reasons and the concrete changes. Keep it to what a reviewer needs — don't pad trivial commits, but always include the summary line and at least one bullet.
- Do **not** add `Co-authored-by` or tool advertising unless the user asked for it.

### 4. Group the work into multiple commits
Before committing anything, map the changes to logical groups. Each **feature group or related unit of work** — a feature and its tests, a bugfix, a docs update, a refactor, a config bump — becomes its **own commit**. This is the default, not an exception: a session that touched three concerns should produce three commits, each with its own scope.

Group by *what the change accomplishes*, not by file type or directory. Keep a feature together with the tests and docs that belong to it rather than splitting them across commits. Don't over-fragment either — a single cohesive change is one commit even if it spans several files.

Commit each group in turn: stage just that group's paths with `git add <paths>` (or `git add -p` for hunks that share a file with another group), then commit before staging the next. Order commits so dependencies land first (e.g. a shared helper before the feature that uses it).

### 5. Commit each group
For each group, stage its paths and commit:

```sh
git add <paths for this group>
git commit -m "type(scope): summary" -m "why in one line

- reason/change bullet
- reason/change bullet"
```

When the user delegated the commit ("commit", "commit my changes"), just do this for every group — no per-commit confirmation. Only show messages for approval first if the user asked you to draft rather than commit. If a commit fails (e.g. a pre-commit hook rejects it), surface the hook output and fix or ask — don't retry blindly or bypass hooks with `--no-verify` unless told to.

### 6. Report the commits as a table
After all groups are committed, print a summary table of what you created so the user sees the result at a glance:

| # | commit message | files |
|---|----------------|-------|
| 1 | `feat(auth): add token refresh retry` | `auth/token.ts`, `auth/token.test.ts` |
| 2 | `chore(repo): bump ci node version` | `.github/workflows/ci.yml` |

List each commit's changed/created files in the last column (get them with `git show --stat --oneline <ref>` or `git diff-tree --no-commit-id --name-only -r <ref>` for the commits you just made). If a commit touches many files, list the key ones and add "+N more". If anything remains uncommitted (intentionally skipped or left for the user), note it under the table.

## Notes

- **Never** run `git push`, `git commit --amend`, or history-rewriting commands unless the user explicitly asks.
- If a repo has its own commit convention (a `CONTRIBUTING.md`, a commit template, or an obviously different style in `git log`), follow that over these defaults and say you did.
- No filesystem or shell? Then you can't run `git` — instead read the diff the user provides and print the finished commit message as a codeblock for them to run themselves.
