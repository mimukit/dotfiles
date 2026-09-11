# Mode: `docs`

Renumber a repo's `docs/` artifacts so a directory listing reads in creation order. Every artifact filename gains a zero-padded serial in front, assigned from when the artifact was created. This is a **one-time migration per repo**, re-runnable and idempotent: a second run on a migrated tree proposes nothing.

This mode touches the filesystem, not GitHub, so the root's `gh` preflight is advisory here — a repo with no GitHub remote can still run it. It needs git for the creation dates and for a recoverable rename. The root's safety stance holds: preview every rename, get an OK, and echo the commands. **It never commits.** The renames land in the working tree for a commit skill to group.

## The rule

`NNNN-<type>-<slug>-YYYY-MM-DD.md`

- **`NNNN`** — a four-digit zero-padded serial, monotonic and never reused. It records creation order.
- **The counter is per directory.** `docs/plans/` and `docs/qa/` each start at `0001`. Numbering a new artifact means scanning its own directory for the highest serial and incrementing, which is one cheap listing.
- **`<type>`** — the artifact type, matching its directory: `plan`, `qa`, `review`, `research`, `adr`, `handoff`, and so on.
- **`<slug>`** — a short lowercase kebab-case subject.
- **`YYYY-MM-DD`** — the ISO **creation** date, kept. The serial gives the order; the date stays readable without opening the file. Both stay fixed when the file is later edited.
- **A bundle directory carries the prefix on the directory**, not on its children: `docs/verify/0004-verify-checkout-2026-07-23/` keeps `notes.md` and `proof.md` fixed inside it.
- **An ADR's decision number is its serial.** `docs/adr/adr-0007-token-ttl-2026-07-23.md` becomes `docs/adr/0007-adr-token-ttl-2026-07-23.md`. The number moves to the front and is never re-derived from a date, because it is the authoritative decision order and other ADRs cite it.

Examples: `docs/plans/0034-plan-sso-login-2026-07-23.md`, `docs/qa/0001-qa-login-throttling-2026-07-23.md`, `docs/adr/0007-adr-token-ttl-2026-07-23.md`.

## 1. Scope the tree

Require a clean working tree first:

```sh
git status --porcelain
```

Uncommitted changes make a bad rename hard to undo, so **stop when the tree is dirty** and ask the user to commit or stash. A repo with no git at all is a hard stop too: without history there is no creation date to order by, and no `git mv` to recover from.

Then list every candidate:

```sh
ls -d docs/*/ 2>/dev/null
find docs -maxdepth 2 -name '*.md' | sort
```

Sort what you find into three sets, and be strict about the third:

- **In scope: dated artifacts.** A file or bundle directory whose name ends in `-YYYY-MM-DD` (with or without a leading serial), sitting in a per-type directory under `docs/`.
- **In scope on the user's word: an undated artifact** in an artifact directory — a repo that wrote `docs/plans/sso-login.md` before any convention. It has a creation date in git even though its name doesn't carry one, so it can be ordered. Ask before including these, and name them individually.
- **Out of scope: reader-facing documentation.** `docs/wiki/`, `docs/how-to/`, `README`-adjacent pages, `index.md`, `architecture.md`, anything a person navigates by name. **A serial in front of a page someone links to is damage, not order.** Never number these, and never ask to.

State the three sets back to the user with counts before going further. This step is done when every `.md` file and bundle directory under `docs/` sits in exactly one of the three sets, and the user has confirmed the second set.

## 2. Order each directory

Work one directory at a time. For each in-scope entry, resolve a creation instant from this ladder, taking the first that answers:

1. **The date in the filename**, when it carries one. It is what the authoring skill recorded as the creation date, and it survives a later `git mv` or a rewritten history that a commit date does not.
2. **The git add time** — `git log --diff-filter=A --follow --format=%aI -1 -- <path>`. This is the whole answer for an undated name, and it breaks ties within a day for a dated one.
3. **The filesystem mtime** — `stat -c %y <path>` (`stat -f %Sm` on macOS). Only reachable for a file git has never seen, such as one inside a gitignored bundle directory.

Sort ascending on that instant, then on the filename to break a remaining tie, and assign `0001` upward. Say which rung each entry landed on when it wasn't the first — an ordering derived from mtime is a guess, and the user should see which ones are guesses.

**`docs/adr/` does not get sorted.** Each ADR keeps the number it already has, moved to the front. Preserve gaps and never compact the sequence, because a gap usually means a decision was withdrawn and its number is still cited. When two ADRs already share a number, stop and report the collision rather than picking a winner.

This step is done when every in-scope entry has a proposed serial, and every serial in a directory is unique.

## 3. Preview and confirm

Print one table per directory: current name, proposed name, and the ordering rung when it wasn't the filename date. Show entries already carrying a correct serial as unchanged rather than dropping them, so the user sees the whole directory.

**Report what the migration cannot decide**, in the same preview: a same-day pair whose order rests on git add time, an ADR collision, any entry ordered by mtime. Get an explicit OK per directory. A user who rejects one directory still gets the others.

## 4. Rename

Use `git mv` for every tracked entry, so the rename is staged and one `git reset --hard` undoes the batch. Use a plain `mv` only for an untracked entry, such as a gitignored bundle.

```sh
git mv docs/plans/plan-sso-login-2026-07-23.md docs/plans/0034-plan-sso-login-2026-07-23.md
```

Rename a bundle directory whole; never touch the files inside it. Echo every command. When one rename fails, report it and continue with the rest rather than abandoning the batch. This step is done when every approved entry is renamed or its failure is reported.

## 5. Repair the references

A rename breaks every link and every mention of the old path. Find them across the whole repo, not only under `docs/`:

```sh
grep -rn 'plan-sso-login-2026-07-23' . --exclude-dir=.git
```

Rewrite each hit to the new name. Check three places a plain grep for the basename can still miss: a Markdown link that wraps the path across a line, an issue or PR body on GitHub (report those, do not edit them), and a skill or script that builds the path from a pattern rather than spelling it out. A pattern-built path is the one that fails silently later, so name any you find. This step is done when a repeat grep for every old basename returns nothing inside the repo, and every out-of-repo mention is listed for the user.

## 6. Record the rule

Look for a documented artifact-naming convention in the repo — `AGENTS.md`, `CONTRIBUTING.md`, or a docs README. When one exists and still describes the old unnumbered shape, propose the updated wording and apply it on an OK. When the repo documents no convention at all, offer to add [The rule](#the-rule) as a short section, and accept a no.

Without this, the next artifact the repo writes has no serial and the tree drifts back within a week. Say that in one line when the user declines.

## 7. Hand off

**What changed.** Give the count renamed per directory, the count left alone and why, and the count of references rewritten. Name every entry ordered by anything below the filename date, so the user can spot-check a guess. Say plainly that nothing is committed.

**Where it landed.** List the directories touched, and the file holding the convention when the run recorded it. Say the renames are staged and one `git reset --hard` reverts them.

**Next.** Crown the commit: the renames are staged and a rename-only commit is the one a reviewer can read, with **commitkit** when installed and `git commit` otherwise. Name any out-of-repo mention the run could not fix — an issue body, a PR description, an external link — as the one thing left for the user to repair by hand.
