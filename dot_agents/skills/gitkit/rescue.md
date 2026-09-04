# Recovering lost work: `gitkit rescue`

Reference for gitkit's [`rescue`](./SKILL.md#rescue) mode. Read this only when work has gone missing; nothing else in gitkit depends on it.

Most work that looks lost is not. A commit stays in the object database after the ref that pointed at it moves, and git keeps a log of every move. The mode reads those logs, shows candidates, and restores by **adding a new branch** rather than by moving anything that exists.

**The whole mode is read-only until the restore step.** Every command below except the last one prints and changes nothing.

## 1. Name the loss

Ask two things: what was in the work, and roughly when it was last seen. A subject line, a filename, or "before the rebase this morning" is enough.

No description, no search. A reflog with no target is a wall of SHAs, and picking one at random is how a rescue makes things worse.

Ends with something to recognize and a rough time window.

## 2. The one case that is not a search

A rebase still in progress restores directly:

```sh
git -C "$WT" status                  # says "interactive rebase in progress" or similar
git -C "$WT" rebase --abort
```

That puts the branch back exactly where it started. Check this before anything else, because it is both the most common cause and the only instant fix.

## 3. Search, in order

```sh
git -C "$WT" reflog                              # HEAD moves in this worktree
git -C "$WT" reflog show "$BRANCH"               # a branch that was reset or deleted
git -C "$WT" show ORIG_HEAD --stat               # where a rebase, merge, or reset started
git -C "$WT" stash list
git -C "$REPO" fsck --lost-found --no-reflogs    # commits no ref and no log remembers
```

- **HEAD reflogs are per-worktree.** Each worktree keeps its own `HEAD` log, so work lost in one worktree is invisible from another. Run the reflog inside the worktree where it happened, and say so when the user is somewhere else. Branch reflogs are shared, which is why the second command works from anywhere.
- **`ORIG_HEAD` is the fastest answer to a bad rebase or a hard reset.** Git writes it before any operation that moves HEAD in bulk, so it is a one-command answer to "where was I".
- **A stash entry is not always in `stash list`.** `git stash create` writes a snapshot commit and touches no ref, which is what `testkit` and `debugkit` use for their baselines. Those SHAs appear only in the output of the run that made them, or in `fsck`. When the user has one of those `git stash apply <sha>` lines from an earlier run, that SHA is the candidate and no search is needed.
- **`fsck` runs last** because it is slow and noisy. Reach for it only when the reflogs came back empty.

Ends with candidate SHAs, each with a subject and a date.

## 4. Show before restoring

```sh
git -C "$REPO" show --stat <sha>
```

Print the subject, the date, and the changed files for each candidate. The user picks one. Guessing on their behalf is how the wrong commit gets restored and the right one gets forgotten.

Ends on a chosen SHA.

## 5. Restore additively

```sh
git -C "$REPO" branch "rescue-<slug>" <sha>
```

**Always a new branch, never a move.** A reset, a checkout over a dirty tree, or a force update is the same class of operation that lost the work in the first place, and it can lose a second thing on the way to recovering the first. A new branch touches nothing that exists, so a wrong candidate costs one `git branch -d`.

For a stash snapshot the equivalent additive form is `git stash apply <sha>`, never `git stash pop`, on a clean tree.

Then let the human take it from there: they merge, cherry-pick, or diff against it. gitkit stops at the branch.

## 6. State the bound

**An unreachable commit survives only until git prunes it.** Reflog entries expire (90 days by default, 30 for unreachable ones) and `git gc --prune=now` ends the window immediately. Say that plainly:

- Recovery gets less likely with time, so a rescue is worth running now rather than later.
- Never run `git gc`, `git prune`, or `git reflog expire` during a rescue. Those are the commands that destroy the thing being looked for.
- When the search comes back empty, say the work is not recoverable through git rather than continuing to look. Uncommitted changes that were never staged or stashed leave no object at all, and no command finds them.

## Hand off

Report the cause when you found one (an aborted rebase, a reset, a deleted branch), the SHA you recovered, and the branch name it now lives on. Name the searches that came back empty.

Next, inspect the rescued branch with `git log rescue-<slug>` and take what you need from it: merge it, or cherry-pick the commits you want.

**Say that `git branch -d` will refuse the rescue branch, and why.** The recovered commits are by definition not in any other branch yet, so git protects them — which is the guard working. Delete it with `-D` only after the work is somewhere else, and confirm that first.
