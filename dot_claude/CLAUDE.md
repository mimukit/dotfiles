## Writing prose

Prose meant for a human reader (docs, READMEs, PR and issue bodies, commit
bodies, chat replies) must not carry the usual AI tells: no em or en dashes as
sentence punctuation, no puffery ("stands as a testament to", "vibrant",
"seamless", "crucial"), no forced triads, no "not only X but also Y", no
signposting ("let's dive in", "here's what you need to know"). Prefer plain
verbs, concrete detail, and uneven sentence length.

For a full rewrite or a review pass over an existing draft, use the `humankit`
skill, which carries the complete pattern catalog.

## Committing

Never commit on your own. Leave every change or new implementation as uncommitted files for the owner to review. The owner reviews first, and only then may they tell you to commit.

The only exception: if the owner's prompt explicitly asks you to commit (and/or push) as part of completing the task, do that. Also '/afkkit' skill can do auto commit and push as that is the core of development automation. Absent that explicit instruction or 'afkkit' skill, do not run git commit or git push — stop after making the edits and let the owner review.

## Cleaning up background processes

Before ending a turn, stop any dev server, test watcher, or other background process you started during that turn (e.g. via Bash `run_in_background`, `wrangler dev`, `pnpm dev`/`turbo run dev`, `vite`, `node --inspect`) — use TaskStop or kill it directly. Don't leave it running "in case it's useful later" unless the user explicitly asked you to keep it up (e.g. for their own manual testing in the browser).

A global Stop hook (`~/.claude/hooks/cleanup-worktree-ports.sh`, invoked via `~/.local/bin/agent-hook`) is a backstop that force-kills anything still listening on a port whose cwd is under an Orca worktree (`~/orca/workspaces/*`) once you stop — but treat that as a safety net, not a substitute for cleaning up yourself.

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

## Agent hooks

Our own Claude Code and Codex CLI hooks route through one dispatcher,
`~/.local/bin/agent-hook` (chezmoi:
`private_dot_local/bin/executable_agent-hook`). It covers three events —
`PreToolUse` (the `rm-guard` delete check), `Notification`, and `Stop` (desktop
toast plus worktree port cleanup) — and each entry in `~/.claude/settings.json`
and `~/.codex/hooks.json` is one line: `bash "$HOME/.local/bin/agent-hook"
<agent> <Event>`. Change hook behaviour by editing the dispatcher, not the JSON.

Orca and herdr install their own entries into those same files and keep them
updated; leave those alone. They coexist with ours by design — Orca strips and
replaces only commands naming its own `agent-hooks/*-hook.sh` script, and appends
its entry after ours. Never wrap a vendor relay inside the dispatcher: Orca would
stop recognising its own entry, reinstall it, and every hook would fire twice.

Orca's relay can be switched off entirely in Orca Settings → "Agent status
hooks", which removes its entries and stops reinstalling them — at the cost of
the working/waiting/done pane indicators.
