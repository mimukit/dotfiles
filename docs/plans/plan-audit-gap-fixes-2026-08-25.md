# Plan: fix the audit gaps

## Context

The 2026-08-25 gap audit (`docs/audit/audit-chezmoi-gaps-2026-08-25.md`) found roughly 40 verified issues across five severity tiers. Two shell bugs can destroy local state today. The weekly secret scan has never run. Codex holds pre-approved `git commit` and `git push` with no counter-instruction. The rest is policy drift, new-machine breakage, CI hardening, and stale docs.

Success means: no tracked script can uninstall a dependency or delete `main` by accident, the scheduled gitleaks run walks full history and fails loudly when it cannot, Codex and Claude carry the same operating rules, every finding in the audit is either fixed or explicitly accepted in a comment, and the audit report can be re-run clean.

## Design decisions (settled)

| Decision | Resolution |
|----------|-----------|
| `brew_apps_cleanup.sh` comparison | Delegate the diff to `brew bundle cleanup --file=… --zap` in dry-run form and parse its output for the interactive menu. The hand-rolled `comm` diff is the bug factory: it misses `--installed-on-request`, mishandles tap prefixes, and carries the `0\n0` count bug. Deleting it removes all three at once. |
| Codex git permissions | Do both halves: drop the `git commit` and `git push` prefix rules from `dot_codex/rules/default.rules`, and add the four missing sections to `AGENTS.md`. A rule enforces, a section explains; either alone leaves a gap. |
| Shared agent-guide body | Make `CLAUDE.md` and `AGENTS.md` chezmoi templates that `includeTemplate` one shared body from `.chezmoitemplates/`. The repo already uses this exact mechanism for three settings payloads. Copy-paste with a "keep in step" comment was rejected; the audit itself caught two files that drifted under that scheme. |
| Fresh-machine ordering | Keep the installer as an `after_` script and document the two-pass apply in the README. Moving it to `before_` re-opens the "Brewfile target not written yet" problem the previous plan deliberately avoided. The real fix is making the fallbacks loud, not reordering the phases. |
| Orca `modify_` fallback | Emit a minimal valid `{"schemaVersion":1,"settings":{},"ui":{}}` plus a stderr warning, mirroring the Claude script's structure. A zero-byte target with exit 0 is the worst of the three current behaviours. |
| herdr hook scripts | Apply the Orca precedent: add both paths to `.chezmoiignore`, `git rm --cached` them, and drop them from the sync lists. The version skew (7 vs 6) already proves they are vendor state, not preference. |
| `dot_codex/private_hooks.json` | Apply the `modify_` pattern with the existing `MARKER=".local/bin/agent-hook"`. This is the fourth instance of the two-writer problem and the third use of the marker; the previous plan's open question said to unify at the third arrival, and this is it. |
| Codex `$HOME` guard | Guard, not a third token variant: `codex_settings_export.sh` exits non-zero when any exported value contains `$HOME`. Document why Codex differs next to the Claude/Orca split note. |
| `.name` / `.email` data keys | Use them in `private_dot_gitconfig.tmpl` rather than delete them. The keys were added for exactly this consumer; wiring them up is one line each and makes the config template honest. |
| External pins | Document the trade-off, do not pin. `zinit self-update` and `tpm`'s own updater would fight a hard pin. Record last-known-good SHAs in the `.chezmoiexternal.toml` header instead. |
| CI action pinning | Pin `actions/checkout` to a full commit SHA with a version comment, and add a Dependabot config for `github-actions` so the pin does not fossilize. |
| gitleaks install | Download to a file, verify the published SHA256 from `gitleaks_<version>_checksums.txt`, extract to `$HOME/.local/bin` without sudo. |
| Markdown wrap in the agent guides | Unwrap both files to one line per paragraph. The rule stays as written; the files stop contradicting it. The shared-body template makes this a one-time fix. |
| Stale Claude approvals | Prune the five dead `permissions.allow` entries from the payload and add a deny list to `claude_settings_export.sh`, mirroring the hook-entry filter it already has. Without the deny list the next `czs` re-imports them. |

## Approach

Six phases, each independently shippable, ordered so the dangerous bugs die first and the CI net tightens before the changes it would catch. The work reuses four things already in the repo: the `modify_` + marker pattern, the `.chezmoitemplates` include mechanism, the `.chezmoiignore` vendor-state precedent with its stated reasons, and the deny-list export pattern.

### Phase 1: defuse the destructive bugs

- Rewrite `private_dot_local/bin/executable_brew_apps_cleanup.sh` around `brew bundle cleanup` output per the settled decision. Delete `extract_brewfile_packages` and the three `grep -c . || echo "0"` count sites.
- Fix `gitcleanmerged` in `dot_zshrc:237` to `git branch --merged main | grep -vE '^\*|^\s*(main|master)$' | xargs -n 1 -r git branch -d`.
- Quote the four unquoted `read -p` prompts in the cleanup script and add `-r`.
- Verify: run the cleanup script on this machine; it must list only formulae absent from the Brewfile, and the "no extras" fast path must be reachable. Run `gitcleanmerged` from a feature branch in a scratch repo; `main` survives.

### Phase 2: make CI honest, then harden it

- Fix `fetch-depth` at `ci.yml:70` to the quoted form `${{ github.event_name == 'schedule' && '0' || '1' }}`. In the scheduled scan step, fail unless `git rev-list --count HEAD` exceeds 100.
- Add `workflow_dispatch` to the triggers, and run the fixed history scan once by hand to confirm it walks full history.
- Add a `concurrency` group with `cancel-in-progress: true`.
- Pin the three `actions/checkout@v4` uses to a SHA; add `.github/dependabot.yml` for `github-actions`.
- Replace the piped `sudo tar` gitleaks install with the checksummed form per the settled decision.
- Make both `git ls-files | grep | while` render loops count their iterations and exit 1 on zero.
- Add a `zsh -n dot_zshrc` step.
- Pin the chezmoi install version, cache the installed binaries on that version string, drop the redundant `apt-get install shellcheck`, add `timeout-minutes` to every job and `persist-credentials: false` to every checkout.
- Verify: one green run on `push`, one green `workflow_dispatch` run whose scan step logs a commit count over 100.

### Phase 3: align the agent governance

- Extract the four shared sections (Committing, Background processes, Deleting files, Agent hooks) into `.chezmoitemplates/agent-shared-rules.md`. Convert `private_dot_claude/CLAUDE.md` and `dot_codex/AGENTS.md` to `.tmpl` files that `includeTemplate` it. Unwrap all prose to one line per paragraph while converting. Fix the `AGENTS.md:46` chat-replies contradiction in favour of the CLAUDE.md split.
- Delete the `git commit` and `git push` prefix rules and the `issue:23` one-off rule from `dot_codex/rules/default.rules`.
- Prune the five stale entries from `.chezmoitemplates/claude-settings.json` and add the exporter deny list per the settled decision.
- Add the `$HOME` guard to `codex_settings_export.sh` with a comment explaining the Codex difference.
- Verify: `chezmoi apply` renders both guide files byte-identical to the pre-conversion content apart from the intended edits, and `czs` after the prune does not re-import the dead approvals.

### Phase 4: enforce the repo's own tracking policy

- Untrack `dot_codex/automations/dot_run-jitter-salt`; add `.codex/automations/.run-jitter-salt` to `.chezmoiignore` with the id-is-not-a-preference reason.
- Untrack both herdr hook scripts per the settled decision; update `chezmoi_sync.sh` lists to match.
- Point the three `automation.toml` prompts at `~/.agents/skills/humankit/SKILL.md`.
- Write `dot_codex/modify_private_hooks.json.tmpl` using the existing marker, seeded from the owned entry; untrack the plain `private_hooks.json`.
- Add the eight GUI-written trees (zed, karabiner, cursor, antigravity, herdr, atuin, topgrade, plus `.codex/rules/` as a directory) to `RE_ADD_PATHS` in `chezmoi_sync.sh`.
- Verify: `chezmoi apply` leaves `~/.codex/hooks.json` vendor entries untouched (diff before and after), and a `czs --dry-run` shows the new trees and no herdr scripts.

### Phase 5: repair the new-machine story

- Fix the Orca `modify_` fallback per the settled decision: stderr warning plus minimal valid JSON.
- Replace `!/opt/homebrew/bin/gh` with `!gh auth git-credential` at both sites in `private_dot_gitconfig.tmpl`; switch name and email to `{{ .name }}` and `{{ .email }}`; rewrite the stale comment in `.chezmoi.toml.tmpl:9-18`.
- Split the 7 `mas` entries out of the bootstrap path: move them to a `Brewfile.mas` installed by hand, or guard the `mas` section so a missing purchase warns instead of failing the apply. Pick during the grill; the plan carries the split as the default.
- Rewrite the README "On a new machine" section: state the two-pass apply, the sudo prompts from casks, and the `mas` behaviour chosen above.
- Verify: `chezmoi apply --dry-run` stays a no-op on this machine after the gitconfig change, and a rendered gitconfig diff shows only the helper and identity lines moving.

### Phase 6: docs, comments, and dead code sweep

- README: correct the four-writer story and drop the brittle hook counts, fix the Orca key count claim, correct the CI-exercises-the-guard sentence, add a CI badge and a short `~/.local/bin` tooling section covering `agent-hook`, `rm-guard`, `git-ssh-sign` and the export scripts.
- `.chezmoiignore`: correct the false `chezmoi add` claim, correct the same mechanism claim in both `modify_` script comments, delete the three dead patterns, tag the surviving preventive patterns with a one-line "blocks chezmoi add" marker.
- `.chezmoiexternal.toml`: extend the header with the pin trade-off and last-known-good SHAs.
- Plan and QA hygiene: stamp follow-up Phase 5 `(built 2026-08-25)`, stamp agent-hook plan Phase 2, repoint the QA doc off the destroyed commit `9598896` onto its existing `diff -q` check.
- Delete dead code: `make_segment`/`make_bar` in `executable_statusline.sh`, `--view` in `executable_ip`, the `git-commit` entry in `dot_skill-lock.json`.
- Small fixes: the two wrong self-path comments (`codex_settings_export.sh:21,92`, `rm-guard:2`), the `sh`/`bash`/direct alias inconsistency and `zxs` ordering in `dot_zshrc`, drop `--debug` from `brew_apps_backup.sh:24`, remove the duplicate `MISE_TRUSTED_CONFIG_PATHS` export from `dot_zshrc:120`, fix the bare `Icon` pattern and add `docs/status/` to `.gitignore`, drop the redundant `act.secrets` line.
- Verify: re-run the audit's check commands (`shellcheck -S warning` over tracked scripts, `chezmoi verify --exclude=externals`, the secrets grep set); all clean.

## Open questions

- `mas` handling in Phase 5: separate opt-in file, or a warn-and-continue guard inside the one Brewfile? The split is cleaner; the guard keeps one file.
- Cursor: the editor is not installed, the `cur` alias is dead, and four config files are tracked. Delete the tracking, or add the cask and keep it? Only the user knows if Cursor is coming back.
- The three export scripts share ~40 duplicated scaffolding lines and have drifted once already. Extract `_export_common.sh` now, or defer until the next time one changes?
- The scheduled workflow still self-disables after 60 days of repo inactivity. Accept with a README note, or drive the weekly scan from an external cron?
- Does converting `CLAUDE.md`/`AGENTS.md` to templates break any tool that reads them from the source repo rather than the applied target?

## Non-goals

- The git history rewrite. Done and verified 2026-08-25; this plan only stamps it.
- Linux portability, unchanged from the previous plan.
- An automated test suite for the shell scripts, still separate work.
- Rewriting the content of vendor-owned hook entries. The `modify_` script for `hooks.json` preserves them; it never edits them.
- Unifying the `__HOME__` `gsub`/`startswith` variants. The Codex guard avoids adding a third variant, which was the trigger condition; the existing two stay as they are.
