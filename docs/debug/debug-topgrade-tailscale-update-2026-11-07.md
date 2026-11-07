# Topgrade Tailscale update failure

The Homebrew Tailscale binary rejects the update command on this Mac. Topgrade calls that unsupported command because its Tailscale step remains enabled.

## Evidence

- The screenshot shows `/usr/bin/sudo /opt/homebrew/bin/tailscale update` and exit status 1.
- `/opt/homebrew/bin/tailscale` links to `../Cellar/tailscale/1.104.5/bin/tailscale`.
- `/opt/homebrew/bin/tailscale update --dry-run` returns the same unsupported-platform error on three consecutive runs without sudo or Topgrade.
- Topgrade reports version 17.15.0. The Homebrew formula and app both report version 1.104.5.
- The source and live Topgrade configuration both leave the `tailscale` step enabled.
- The Brewfile includes `brew "tailscale"` and `cask "tailscale-app"`.
- `dot_zshrc:149` defines `brewupx` to run `brew update && brew upgrade --greedy --verbose --yes && brew cleanup --prune=all`.

## Mechanism

Tailscale selects an update function for each platform and distribution. Its macOS branch supports the App Store and system extension app builds. The default macOS branch returns no update function. The Homebrew command takes that unsupported path.

Source: https://github.com/tailscale/tailscale/blob/main/clientupdate/clientupdate.go

## Reproduction

Run `/opt/homebrew/bin/tailscale update --dry-run`. The command fails with `The 'update' command is not supported on this platform; see https://tailscale.com/s/client-updates`.

This command requests no installation changes. It remains the failing reproduction for a separate fix task.

## Separate path observation

The current shell selects `/usr/local/bin/tailscale`. That file calls `/Applications/Tailscale.app/Contents/MacOS/Tailscale`. The current Topgrade dry run also selects this wrapper. The screenshot selects the Homebrew binary instead. The PATH differs between these executions; this run does not establish why.

The app wrapper fails with `Failed to load preferences` in this execution environment. This result does not establish an app failure in the normal desktop session. Changing PATH alone is not a verified fix.

## Recommended change

Add `"tailscale"` to `[misc].disable` in `dot_config/topgrade.toml`. Apply that target with ChezMoi. Use the existing `brewupx` command to update the formula and app through Homebrew. Check a full Topgrade dry run for the absence of a Tailscale update command.

No fix is applied. No upgrade runs. The direct failure reproduces, but this run does not toggle the installed build to complete debugkit’s full cause-removal test. Treat the diagnosis as reproduced with source evidence, rather than a completed on/off proof.

## Baseline

The working tree starts clean at `f904959ef373587fc685fe60e9a59f61e8421103`. No existing tracked file changes. The index remains unchanged. This report is the only new repository file. No probe edits require reversal.

Baseline snapshot is none because no tracked change exists at the start. The read-only probe records are in `/tmp/tailscale-topgrade-debug`.
