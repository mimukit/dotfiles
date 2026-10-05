## Mode: `align`

One-time configuration, per machine. It does not touch a single workspace.

**Check the worktree root.** Compare `worktrees.root` in `~/.paseo/config.json` against `$WORKTREE_ROOT`, which is gitkit's convention, defaulting to `~/worktrees` unless the environment says otherwise. Two roots in play means every sweep classifies by path forever.

Aligning it **only affects worktrees Paseo creates itself**. Existing worktrees are untouched, and git stores absolute paths, so nothing moves. Say that out loud, because "aligned" reads like "migrated" and it is not.

**Aligning the roots does not arm the delete.** Paseo's delete test wants `<worktrees.root>/<hash>/<slug>`, and a gitkit worktree carries the repo name where the hash belongs, so it keeps failing the test after alignment exactly as it did before. Say that plainly when the user asks whether alignment is risky. What alignment changes is that Paseo's own new worktrees land beside gitkit's instead of under `~/.paseo/worktrees`, which puts two naming schemes in one directory. That is the real trade to name.

**Surface `daemon.autoArchiveAfterMerge`, and let the user choose.** Setting it `true` lets Paseo archive a workspace by itself when its change request merges. It carries its own gates, listed in [the version seam](../SKILL.md#the-version-seam). Those match `clean`'s own gates, so the switch is a fair native shortcut for the Paseo-created half. What it still skips is the preview and the confirmation, and it stops the agents and kills the terminals without asking. It reaches no gitkit worktree at all, so it never replaces `clean` on this machine's own worktrees.

### Hand off

**What changed.** Report which config keys you compared, and which the user chose to change.

**Where it landed.** Report `~/.paseo/config.json`. Repeat that existing worktrees stayed where they were.

**Next.** Run [`list`](../SKILL.md#mode-list) to see the whole set in one table. Then stop. This is a one-time setting per machine, not a routine.
