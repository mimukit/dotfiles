# Preparing a worktree: `gitkit prepare`

Reference for gitkit's [`prepare`](./SKILL.md#prepare) mode. Read it when a caller hands a new or adopted worktree to a person or an agent, when a [sync](./SKILL.md#sync) took commits on a prepared worktree, and when [Remove](./SKILL.md#remove) meets a prepared worktree.

A fresh worktree is a bare checkout: no dependencies, no `.env`, no database. `prepare` makes it ready to run by executing the commands **the repository declares**, and `teardown` undoes what they made before the worktree goes. gitkit chooses *when* each one runs. The repository chooses *what* runs: gitkit never names a database, picks a port, or guesses a seed command. The one command gitkit infers is the install a lockfile implies, and only when the repository declares nothing.

## The declaration

A repository declares its worktree setup in a `## Worktree setup` section of its agent-guide file: `AGENTS.md` at the worktree root, else `CLAUDE.md`. Read the file **from the worktree**, not from the main checkout, because the branch may have changed it.

The section holds up to four labels. Each label is a line of its own, followed by one fenced block:

- **`setup:`** (required). Makes the worktree ready from nothing: install, copy untracked files, create and migrate the database, seed it. **It must be safe to re-run**, because an explicit "prepare again" and a change without an `update:` both run it on a worktree that is already set up.
- **`update:`** (optional). Brings a prepared worktree up to date after a change, usually install and migrate with no seed, so a re-run never overwrites the test data someone made by hand.
- **`teardown:`** (optional). Removes what `setup:` made outside the worktree directory, such as the worktree's database. Files inside the worktree need no teardown, because the removal deletes them.
- **`watch:`** (optional). One glob per line, relative to the worktree root. A change to a matching path makes the next prepare run `update:`. The lockfiles are always watched, so list only the repository's own paths, such as its migration and seed directories.

Every block runs from the worktree root as `bash -e`, so the first failing command stops it. gitkit exports three variables to every block:

| variable | value |
|---|---|
| `GITKIT_REPO` | absolute path of the main checkout |
| `GITKIT_WORKTREE` | absolute path of this worktree |
| `GITKIT_BRANCH` | the branch checked out in this worktree |

**Secrets are the repository's to move.** A setup that needs `.env` copies it from `"$GITKIT_REPO"` itself. gitkit never reads, copies, or prints a secret file.

### The template

Print this when a repository declares nothing, adapted to the lockfile it has:

~~~markdown
## Worktree setup

setup:
```sh
cp "$GITKIT_REPO/.env" .env
pnpm install --frozen-lockfile
pnpm db:setup && pnpm db:seed
```

update:
```sh
pnpm install --frozen-lockfile
pnpm db:migrate
```

teardown:
```sh
pnpm db:drop
```

watch:
```text
db/migrations/**
db/seed/**
```

`setup:` must be safe to re-run. Name the worktree database after `$GITKIT_BRANCH`, so two worktrees never share one.
~~~

## The marker

```sh
MARK="$(git -C "$WT" rev-parse --absolute-git-dir)/gitkit-prepared"
git -C "$WT" rev-parse HEAD > "$MARK"     # after a setup or update that exits 0
```

`gitkit-prepared` sits in the worktree's admin directory, next to `gitkit-created`, and holds the `HEAD` SHA of the last run that passed. It records two facts. **gitkit prepared this worktree**, so teardown may run. And **the worktree was ready at this commit**, so the change check has a starting point. `git worktree remove` deletes it with the worktree. A failed run never writes it.

## The lockfiles

A repository with no `## Worktree setup` section gets the install its lockfile implies, and nothing else. This table is also the set of lockfile names the change check always watches, at any depth:

| lockfile | install |
|---|---|
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `package-lock.json` | `npm ci` |
| `yarn.lock` | `yarn install --immutable` (Berry) or `yarn install --frozen-lockfile` (v1, when `.yarnrc.yml` is absent) |
| `bun.lock`, `bun.lockb` | `bun install --frozen-lockfile` |
| `uv.lock` | `uv sync --locked` |
| `poetry.lock` | `poetry install` |
| `Gemfile.lock` | `bundle install` |
| `go.sum` | `go mod download` |

Read only the lockfiles at the worktree root. More than one install lockfile at the root (`pnpm-lock.yaml` beside `package-lock.json`) is ambiguous: name them, run nothing, and print the template so the repository can declare which one is real. No lockfile and no section means there is nothing to prepare; say so.

## `prepare`

### 1. Read the declaration

Find the `## Worktree setup` section and each labelled block in it. A label with no fenced block after it is a broken declaration: name the label and stop, rather than run a half-read section. Ends when each of the four labels is read or known to be absent, or when no section exists.

### 2. Decide what runs

Take the first row that matches:

| state | runs |
|---|---|
| the human asked to "prepare again" | `setup:`, or the lockfile install |
| no marker | `setup:`, or the lockfile install |
| marker, and a watched path changed since its SHA | `update:`, else `setup:`, or the lockfile install |
| marker, and nothing watched changed | nothing |

The change check:

```sh
SHA=$(cat "$MARK")
git -C "$WT" diff --name-only "$SHA" HEAD     # match each path against the lockfile names and the watch: globs
git -C "$WT" rev-list --count "$SHA"..HEAD    # how far HEAD moved, for the report
```

**A marker SHA that git cannot resolve counts as a change.** A rebase replaces the commits, and the old SHA lives only until git prunes it. When `git cat-file -e "$SHA^{commit}"` fails, run `update:` rather than guess that nothing moved.

Ends with one named action, or with "nothing changed since `<sha>`".

### 3. Run it

```sh
log="${TMPDIR:-/tmp}/gitkit-prepare-$(basename "$WT").log"
( cd "$WT" && GITKIT_REPO="$REPO" GITKIT_WORKTREE="$WT" GITKIT_BRANCH="$BRANCH" bash -e -c "$BLOCK" ) >"$log" 2>&1
echo "exit $?"; tail -n 30 "$log"
```

Run the block once, into a log. A non-zero exit stops prepare: report the block, the exit code, and the tail, and leave the marker as it was. An unattended caller gets the same three facts returned, to escalate in its own way. Never re-run a failed block with changes of your own; the declaration is the repository's, and a fix belongs in it.

Ends with exit 0, or with the failure reported.

### 4. Write the marker

Write the `HEAD` SHA to the marker, as [The marker](#the-marker) shows. Ends when the marker holds the SHA the block ran at.

### Hand off

**What changed.** Name the action: `setup:`, `update:` and the watched paths that triggered it, the lockfile install, or nothing. Give each block's exit code. After a skip, give the marker SHA and how many commits `HEAD` moved since it.

**Where it landed.** Give the worktree path and the marker SHA. For an undeclared repository, say "lockfile install only, no worktree setup declared" and print [the template](#the-template). When another skill called `prepare`, return these facts to it and print nothing else.

**Next.** When the human asked directly, name the repository's own command that starts the app, from its scripts or its agent-guide file. Name none when the repository documents none.

## Teardown

[Remove](./SKILL.md#remove) runs this after its dirty check and its confirmation, and before `git worktree remove`, because the declared command and the scripts it calls live in the worktree that is about to go.

1. **Check both conditions.** The marker exists, and the worktree's own agent-guide file declares `teardown:`. When either is absent, run nothing: without the marker gitkit did not prepare this worktree, and without the block there is nothing to undo. Ends with a run or a named skip.
2. **Run the block** exactly as [Run it](#3-run-it) runs one, with the same three variables. Ends with an exit code.
3. **A failure keeps the worktree.** Report the block, the exit code, and the tail, and stop the removal of this worktree. The worktree is the only handle on whatever the teardown failed to remove, so removing it would orphan that resource. Ends with the removal allowed, or stopped with its reason.

When teardown leaves new untracked files behind, `git worktree remove` refuses. Report the files; never reach for `--force`.

The confirmation that covers a removal covers its teardown, and [the merged-PR exception](./SKILL.md#remove) covers it with no prompt. The hand-off of the removal names the teardown block and its exit code.
