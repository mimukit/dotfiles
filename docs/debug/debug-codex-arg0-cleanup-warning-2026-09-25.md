# Codex warning: failed to clean up stale arg0 temp dirs

## Symptom

Running `codex` prints `WARNING: failed to clean up stale arg0 temp dirs: Permission denied (os error 13)`. The expected result is a clean start. Seen on this Mac, codex at `/opt/homebrew/bin/codex`.

## Cause (proven)

A root-owned directory sits in `~/.codex/tmp/arg0/`. The parent is owned by `mukit`, so `mukit` can see the directory but cannot delete the files inside it. Codex tries to remove stale `codex-arg0*` directories at start, gets EACCES, and prints the warning.

The directory is `~/.codex/tmp/arg0/codex-arg02KMNK2`, created on Sep 23 at 20:58. It holds a root-owned `.lock` and three symlinks to `/opt/homebrew/bin/codex`. Someone ran codex once as root (for example with `sudo`) on that date. Every other entry in the directory belongs to `mukit`.

## Proof

The test ran in a scratch `CODEX_HOME`, not in `~/.codex`. A stale directory with mode 555 gives the same unlink denial as a root-owned one.

| Step | State | Warning | Stale dir after run |
|---|---|---|---|
| A | writable stale dir | no | removed |
| B | mode 555 stale dir | yes | stays |
| C | same dir, mode 755 | no | removed |
| D | new mode 555 stale dir | yes | stays |

## Fix (not applied)

Remove the root-owned directory once, with `sudo rm -rf ~/.codex/tmp/arg0/codex-arg02KMNK2`. Then run `find ~/.codex -user root` to look for other root-owned files. Do not run codex with `sudo` again.

## Not a dotfiles bug

The chezmoi source does not create this directory. The `Found existing alias for "codex"` line is a separate hint from an alias plugin and is harmless.
