## Committing

Never commit on your own. Leave every change or new implementation as uncommitted files for the owner to review. The owner reviews first, and only then may they tell you to commit.

The only exception: if the owner's prompt explicitly asks you to commit (and/or push) as part of completing the task, do that. Also '/afkkit' skill can do auto commit and push as that is the core of development automation. Absent that explicit instruction or 'afkkit' skill, do not run git commit or git push — stop after making the edits and let the owner review.

## Deleting files

You may delete files and directories when it is clearly safe. A shared guard
(`~/.local/bin/rm-guard`, policy tier: Balanced) enforces the boundary
automatically on every Bash delete, so do not pre-emptively refuse safe deletes
or route them to a manual to-do list — just run the `rm`.

- **Safe — proceeds without prompting:** temp files/dirs (`/tmp`, `$TMPDIR`,
  `/var/folders`, the session scratchpad) and git-*tracked* files inside a repo
  (recoverable via git). `trash` and `git rm` of tracked files are also safe.
  Delete these freely when the task calls for it.
- **Risky — the guard will prompt the owner to confirm:** untracked files inside
  a repo, any `rm -rf` of a directory, globbed/unknown target sets, `..`
  traversal, `sudo` or `xargs`-fed deletes, `git clean`, and anything outside a
  repo and outside temp. Go ahead and issue the command; the owner gets a prompt.
- **Catastrophic — always blocked by the guard:** `/`, `$HOME` root, system
  roots (`/Users`, `/System`, `/etc`, `/usr`, …), and globs anchored at those
  roots. Never attempt these.

Only fall back to handing the owner a manual `rm` (as a to-do) when the guard
blocks the operation, or when you genuinely cannot tell whether a delete is
safe. If a delete you expected to succeed is denied, don't retry it in different
ways — surface it to the owner instead.
