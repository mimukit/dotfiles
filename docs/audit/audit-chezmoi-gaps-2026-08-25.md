# Audit: remaining gaps in the chezmoi repo

Date: 2026-08-25. Scope: the full repo, minus the six items in `docs/plans/plan-chezmoi-audit-followups-2026-08-25.md`. Four parallel reviews covered the shell layer, the chezmoi machinery, CI and docs, and the agent config surface. Every finding below was verified against the file, and many against live state.

One status correction first. Phase 5 of the follow-up plan is done but not marked. The pack is 2.06 MiB, `main` matches `origin/main`, and no bundle remains on the Desktop. Mark the phase built in the plan.

## Severity 1: can destroy work or state

### 1.1 `brew_apps_cleanup.sh` offers to uninstall 165 dependency formulae

`private_dot_local/bin/executable_brew_apps_cleanup.sh:54-57,73`. The script compares the Brewfile's 102 explicit `brew` lines against `brew list --formula`, which lists all 267 installed formulae, dependencies included. It then offers `brew uninstall --ignore-dependencies` on each of the 165 "extras". One accepted prompt breaks most of what the Brewfile installs. The sed extraction also keeps tap prefixes and `, trusted: true` suffixes, so `opencode`, `localias`, `infisical`, `taproom` and `supercmd` always show as extra. Fix: compare against `brew list --installed-on-request`, and strip the tap prefix, or replace the hand diff with `brew bundle cleanup --file=…`.

### 1.2 `gitcleanmerged` can delete your local `main`

`dot_zshrc:237-239`. The filter `grep -v '^\* main'` removes `main` only when `main` is the current branch. Run the alias from a feature branch and `git branch -d main` succeeds. Fix: `grep -vE '^\*|^\s*(main|master)$'`.

### 1.3 The weekly gitleaks history scan has never run

`.github/workflows/ci.yml:70`. `fetch-depth: ${{ github.event_name == 'schedule' && 0 || 1 }}` always yields `1`, because the expression engine treats the unquoted `0` as false. The schedule run scans a one-commit shallow clone and passes green. This scan is the stated reason the schedule exists. Fix: quote the values as `'0'` and `'1'`, and assert `git rev-list --count HEAD` is large in the scan step.

### 1.4 Codex has `git commit` and `git push` pre-approved with no counter-rule

`dot_codex/rules/default.rules:1-4` allows both commands. `dot_codex/AGENTS.md` carries none of the four control sections that `private_dot_claude/CLAUDE.md` has: Committing, Background processes, Deleting files, Agent hooks. The agent with the weakest instructions holds the strongest permission, on the same machine and the same hooks. Fix: drop the two prefix rules, and copy the four sections into `AGENTS.md`, or extract a shared body both files include.

## Severity 2: breaks the new-machine story

### 2.1 The first apply runs the `modify_` scripts before `jq` and `uv` exist

The Brewfile installer is an `after_` script, so a fresh machine runs the file phase first, without `jq` or `uv`. The Claude script falls back and writes literal `__HOME__` strings into `~/.claude/settings.json`. The Orca script (`modify_orca-data.json.tmpl:55-61`) prints nothing, exits 0, and chezmoi writes a zero-byte `orca-data.json` with no error message. A second apply heals both, but the README never says to run it twice. Fix: add a stderr message and a non-zero exit to the Orca fallback, and either document the two-pass requirement or move the brew bootstrap to a `before_` script that reads the Brewfile from the source dir.

### 2.2 The bootstrap cannot finish unattended, and the README says it is automatic

`.chezmoiscripts/run_onchange_after_install-packages.sh.tmpl` runs `set -euo pipefail` over 87 casks, 102 brews and 7 `mas` entries. Casks prompt for the admin password, and `mas "Xcode"` fails on an account that never bought it, which stops the whole apply. Fix: split the `mas` block into an opt-in step, or state the limits in `README.md:50`.

### 2.3 `chezmoi_sync.sh` never re-adds eight GUI-written config trees

`private_dot_local/bin/executable_chezmoi_sync.sh:65-94`. Zed, Karabiner, Cursor, Antigravity, herdr, atuin and topgrade files are tracked but absent from `RE_ADD_PATHS`. A setting changed in those UIs never reaches the source, and the next apply overwrites it. `chezmoi status` is clean today, so nothing is lost yet. Fix: add the trees to the list, or document each omission the way the script already documents `settings.json`.

### 2.4 The gitconfig hardcodes the Apple-Silicon brew prefix

`private_dot_gitconfig.tmpl:17,19` pins `!/opt/homebrew/bin/gh`. Intel Macs use `/usr/local`. Fix: `!gh auth git-credential`. Related: `.chezmoi.toml.tmpl:9-18` defines `.name`, `.email` and `.home`, and no template uses any of them, while the gitconfig still writes name and email literally. The comment above the keys also misdescribes the file it points at. Use the keys or delete them, and fix the comment.

## Severity 3: policy violations against the repo's own rules

### 3.1 A per-install UUID is tracked in the public repo

`dot_codex/automations/dot_run-jitter-salt` is one UUID. `.chezmoiignore` already withholds `coderabbit.machineId` and Orca's `telemetry.installId` on the stated rule that an id is not a preference. Fix: add it to `.chezmoiignore` and `git rm --cached` it.

### 3.2 The herdr hook script is tracked twice against the Orca precedent

`private_dot_claude/hooks/executable_herdr-agent-state.sh` and `dot_codex/executable_herdr-agent-state.sh` are vendor-written, rewritten on every herdr upgrade, and already at different versions (7 and 6). `.chezmoiignore` refuses the identical case for Orca hooks. `chezmoi_sync.sh` re-adds both on every `czs`, so each herdr release lands as source churn. Fix: ignore both paths and drop them from the sync lists, or write down why herdr differs from Orca.

### 3.3 Three automations point at a skill that does not exist

`dot_codex/automations/*/automation.toml:5` in three automations reads `/Users/mukit/.agents/skills/humanizer/SKILL.md`. The skill is now `humankit`. Every scheduled run silently skips the humanizer pass. This is also the last user-owned hardcoded `/Users/mukit` outside the plan's scope. Fix: point at `~/.agents/skills/humankit/SKILL.md`.

### 3.4 Stale one-off approvals sit in the public Claude payload

`.chezmoitemplates/claude-settings.json:31-38`. Two entries allow `statusline-command.sh`, a script that exists nowhere. Three more are debug leftovers such as `Bash(echo "---EXIT: $?---")`. The exporter filters hooks by owner but passes `permissions.allow` through verbatim, so every clicked approval becomes permanent and public. Fix: prune the five entries, and give `claude_settings_export.sh` a small deny list for the allow array.

### 3.5 Codex is the only payload with no `$HOME` guard

`executable_codex_settings_export.sh` has no `__HOME__` handling. The payload holds no paths today, but the deny-list policy admits path-valued keys, so one policy change puts `/Users/mukit` into the public repo. Fix: make the exporter exit non-zero when an exported value contains `$HOME`, and document why Codex differs.

### 3.6 `dot_codex/private_hooks.json` is the last vendor-cowritten file tracked whole

Orca and Paseo entries interleave with the one owned `agent-hook` entry, so every vendor upgrade puts a diff in the source. This is the exact two-writer problem the `modify_` pattern solved for Claude and Codex settings, and the existing `MARKER=".local/bin/agent-hook"` would work verbatim. Fix: apply the `modify_` pattern, or accept the churn in a header comment.

## Severity 4: CI hardening

All in `.github/workflows/ci.yml`.

- Pin the three `actions/checkout@v4` uses to a commit SHA, and add Dependabot for `github-actions` (`:25,68,94`).
- Add a `concurrency` group with `cancel-in-progress` (`:7-12`).
- Add `workflow_dispatch`. GitHub also disables `schedule` after 60 days of repo inactivity, so note that or drive the scan externally (`:11-12`).
- The gitleaks tarball pipes into `sudo tar` with no checksum. Verify the published SHA256, and extract to `$HOME/.local/bin` without sudo (`:73-76`).
- Both `git ls-files | grep | while` render loops exit 0 when they match nothing. Fail on a zero count (`:40-44,111-114`).
- Nothing checks `dot_zshrc`, and a broken alias is a stated reason CI exists. Add `zsh -n dot_zshrc` (`:55`).
- Pin the chezmoi version, cache the installed binaries, drop the redundant `apt-get install shellcheck`, and add `timeout-minutes` plus `persist-credentials: false`.

## Severity 5: docs, comments, and dead code

- `README.md:104-106` says three writers and stale hook counts. There are four writers now, Paseo included, and the counts are wrong. The Orca key count at `:74` is 157, not 151.
- `README.md:50` claims CI exercises the brew guard. CI passes `--exclude=scripts`, so it never runs the script. It renders and lints it only.
- The README does not mention CI, `agent-hook`, `rm-guard`, or the `dot_agents/skills` set at all. Add a badge and one tooling section.
- `.chezmoiignore:41-43` claims `chezmoi add` bypasses the ignore file. Verified false on v2.72.0, which warns and refuses. The two `modify_` script comments about `chezmoi add` also describe the wrong mechanism, replacement rather than shadowing. Three patterns (`**/.DS_Store`, the zed prompts line, the `*.tmp` block) match nothing anywhere. Correct the comments and prune or tag the dead patterns.
- `.chezmoiexternal.toml` pins neither zinit nor tpm, while yazi and nvim plugins are pinned. Self-update makes a hard pin awkward, so at minimum record the trade-off and last-known-good SHAs.
- `private_dot_claude/CLAUDE.md:50` and `dot_codex/AGENTS.md:58` forbid hard-wrapped Markdown and are themselves hard-wrapped. `AGENTS.md:46` also puts chat replies in the third-party prose bucket, which contradicts CLAUDE.md. Unwrap both and align the split.
- Plan and QA hygiene: mark follow-up Phase 5 built, mark agent-hook plan Phase 2 built, and repoint `docs/qa/qa-agent-hook-notifications-2026-08-22.md` off commit `9598896`, which the rewrite destroyed.
- `dot_agents/dot_skill-lock.json` carries a `git-commit` entry with no skill dir anywhere. Remove or reinstall.
- Dead code: `make_segment`/`make_bar` in `executable_statusline.sh:127-152` (26 unreachable lines), `--view` in `executable_ip`, the `cur` alias plus four tracked `dot_config/cursor` files for an editor that is not installed, and rule 8 in `dot_codex/rules/default.rules` pinned to `issue:23`.
- Small bugs: the `grep -c . || echo "0"` fallback in `brew_apps_cleanup.sh:65-103` yields the string `0\n0`, so the "no extras" fast path is unreachable; `codex_settings_export.sh:21,92` names the modify script by a wrong filename; `rm-guard:2` states its own source path wrongly; the three export scripts duplicate ~40 lines of scaffolding and have already drifted; `MISE_TRUSTED_CONFIG_PATHS` is set in both `dot_zshrc:120` and the mise template; `.gitignore` has a bare `Icon` pattern and no `docs/status/` entry.

## Verified clean

Secrets scan over all 180 tracked files found nothing. No `.DS_Store` is tracked. All 34 skill symlinks map 1:1 onto skill dirs. `chezmoi verify --exclude=externals` exits 0. The `run_onchange` Brewfile hash matches byte for byte. The `.chezmoiversion` floor is safe. The automation prompts and `memory.md` carry no credentials.
