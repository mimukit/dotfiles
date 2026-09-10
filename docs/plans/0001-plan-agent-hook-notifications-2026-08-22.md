# Plan: agent-hook notification context and click-to-focus

## Context

`agent-hook` sends two fixed strings. `feat_notify` at `private_dot_local/bin/executable_agent-hook:81` takes a message argument, and the dispatcher only ever passes `"Awaiting your input"` or `"Task completed"`. The toast names the agent and nothing else.

Two costs follow from that. A toast does not say which repo woke you, so you check each session by hand. A toast does not go anywhere on click, so you find the pane yourself. `terminal-notifier -list ALL` shows nine identical entries from one morning, which is the pile-up the missing `-group` flag allows.

Research on 2026-08-22 rejected code-notify and anotifier. Neither focuses a tmux window on macOS. anotifier ships click-to-focus for Windows only and calls `osascript` on macOS, and AppleScript `display notification` registers no click handler. code-notify activates an app and stops there. code-notify also writes the Codex `notify` key, which `~/.codex/config.toml:3` already assigns to Codex Computer Use.

Success means one thing. A toast tells you the repo, the branch and the reason, and a click puts the cursor in the pane that sent it.

## Design decisions (settled)

| Decision | Resolution |
|----------|-----------|
| Build or install | Extend `agent-hook`. Neither third-party tool does tmux click-to-focus on macOS, and both would lose the six-variable suppression list at line 50. |
| Notification binary | Keep `terminal-notifier`. A probe delivered a banner on macOS 26.6.2 today. The Tahoe failure reports apply to `-sender` bundle impersonation, which we do not use. |
| Click mechanism | `terminal-notifier -execute`. It returns in 0.27s and does not block, so the hook stays inside its 10s budget. `alerter` blocks until click and would need a background subshell. |
| Reason source | The `matcher` field on the settings entry, passed to `agent-hook` as a third argument. The Notification payload's own field names are unconfirmed, and a matcher needs no parsing. |
| Focus target | Detect at hook time. `$TMUX` wins, `$ITERM_SESSION_ID` is the fallback, and a bare `open -a` is the floor. Hooks inherit Claude Code's environment, so both variables reach the hook. |
| Toast dedup | Add `-group` keyed on `session_id`. A new toast then replaces the stale one from the same session. |
| Suppression | No change. The `NOTIFY_SUPPRESS_VARS` list stays as it is. A suppressed toast needs no focus target. |
| Where the code lives | `feat_notify` and two new helpers in `executable_agent-hook`. Matchers go in `.chezmoitemplates/claude-settings.json`. |

## Approach

The dispatcher already reads the payload once into `$payload`, already has `payload_get` for jq extraction, and already computes `$PROJECT_DIR` at line 142 and then discards it. All three get reused. The change adds two helpers and rewrites `feat_notify`.

### Phase 1: put context in the message (built 2026-08-22)

Give `feat_notify` a real title, subtitle and body.

1. Add `notify_subtitle()`. It reads `$PROJECT_DIR`, takes the repo name with `basename`, and reads the branch with `git -C "$PROJECT_DIR" symbolic-ref --short HEAD`. It prints `chezmoi · main`. It prints the repo name alone when git fails.
2. Change the `terminal-notifier` call at line 91 to pass `-subtitle`.
3. Add `-group` with the value from `payload_get '.session_id'`. Fall back to `$PROJECT_DIR` when the payload carries no session id.
4. Pass the reason through. Add a third positional argument to the dispatcher, so `agent-hook claude Notification permission_prompt` reaches `feat_notify` as the body text.
5. Map each matcher value to a short body string. `permission_prompt` becomes `Needs permission`. `idle_prompt` becomes `Waiting for you`. An empty or unknown value keeps `Awaiting your input`.
6. On `Stop`, read `last_assistant_message` with `payload_get`, cut it to about 80 characters, and use it as the body. Keep `Task completed` when the field is absent.

Verify with `terminal-notifier -list ALL`. The new rows must show a subtitle and a group id.

### Phase 2: add click-to-focus

Build the `-execute` command string and attach it.

1. Add `notify_focus_cmd()`. It prints a shell command, or prints nothing when it cannot find a target.
2. Handle the tmux case first. When `$TMUX` is set, read the target with `tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_index}.#{pane_index}'`. Print `tmux switch-client -t <session> \; select-window -t <window> \; select-pane -t <pane>`, then append `open -a <app>`.
3. Pick the app from `$TERM_PROGRAM`. Map `iTerm.app` to `iTerm`, `ghostty` to `Ghostty`, `WezTerm` to `WezTerm`. Default to `iTerm`, which is the terminal in use.
4. Handle the iTerm2 case second. When `$TMUX` is empty and `$ITERM_SESSION_ID` is set, print an `osascript` call that selects the iTerm2 session with that id and then activates iTerm.
5. Handle the floor case last. Print `open -a <app>` when `$TERM_PROGRAM` is set, and print nothing otherwise.
6. Pass the result to `terminal-notifier -execute`. Skip the flag when the helper prints nothing.
7. Quote the command string once. `-execute` takes one shell command, and a repo path with a space must survive it.

Verify by clicking a banner from a tmux pane in one session while a second session holds focus.

**Status on 2026-08-22.** The code is written and `notify_focus_cmd` produces the right command for all three branches. A real tmux server resolved `%20` to `default:1.1` and `%1` to `system_updates:1.1`, `sh -c` ran the generated tmux chain with exit 0, and `osacompile` accepted the AppleScript. The click itself is still unproven, because `terminal-notifier -execute` has not been observed firing on macOS 26. That is the last step, and the open question below carries it.

### Phase 3: wire the matchers and roll out (built 2026-08-22)

1. Give `.chezmoitemplates/claude-settings.json` one `Notification` entry per matcher. **No catch-all.** The docs state an empty matcher means "match all" and that "all matching hooks run in parallel", so an empty entry alongside `permission_prompt` fires the hook twice for one event. The five entries cover all nine documented types, and the fifth uses `|` alternation for the five types that need no special wording.
2. Append the matcher value to each command string, so each entry calls `agent-hook claude Notification <type>`.
3. Leave `~/.codex/hooks.json` alone. Codex has no matcher support, and the dispatcher comment at line 60 already records that. Codex keeps the generic body.
4. Run `chezmoi diff` and confirm the merge script touches only our three entries. The Orca, herdr and Paseo entries must not move.
5. Run `chezmoi apply`, then run `/hooks` in Claude Code and confirm four Notification entries appear.
6. Update the header comment block. The scope list at line 15 says `Notification  desktop toast`, which no longer describes what the feature does.

### Rejected alternatives

- **Swap `terminal-notifier` for `alerter`.** It uses the current `UNUserNotificationCenter` API, but it blocks until click and needs a background subshell. Hold it as the fallback if Phase 2 finds `-execute` dead.
- **Use Claude Code's native OSC 9 notification.** It needs one tmux line and no code, but it carries generic text and offers no click action. Worth adding as a second channel, not as this feature.
- **Read the transcript file for the reason.** `transcript_path` is in the payload, but parsing JSONL inside a 10s hook is slower and more brittle than `last_assistant_message`.

## Open questions

- **Does `-execute` fire on macOS 26.6.2?** Still open, and it is the only thing between Phase 2 and done. A probe banner titled `researchkit click probe` is unclicked. Click it, then run `ls /tmp/tn-click-probe`. If the file is missing, install `alerter` and swap the `-execute` branch of `feat_notify` for `@CONTENTCLICKED`. Nothing else in the plan depends on this.
- **Does a new notification type lose its toast?** Yes, by design. Dropping the catch-all removed the double-fire, and the cost is that a tenth type added by a future Claude Code release matches no entry. Re-check the matcher list when Claude Code ships a new notification type.
- **Which client does `tmux switch-client` move** when two iTerm2 tabs attach to different sessions? Untested with two clients. The command chain itself ran clean against the live server.
- **Does the 80-character cut land well?** `notify_stop_body` flattens and truncates `last_assistant_message`. A long first sentence gives a toast that stops mid-clause.

### Settled during the build

- **The Notification payload's own field names stayed unread.** Matcher routing made the question moot. `$3` carries the type and no jq parsing is needed.
- **The reason map lives in the script**, in `notify_reason`. The settings template stays declarative and carries only the matcher name.

## Non-goals

- **Off-machine push.** No ntfy, Slack, Discord or webhook. Deferred until you ask for it.
- **Third-party notifier tools.** code-notify and anotifier stay uninstalled. See the research artifact for why.
- **Changing the suppression list.** Orca, herdr and Paseo keep their existing behaviour.
- **Quiet hours, per-project mute and rate limiting.** Not requested.
- **Codex matcher parity.** Codex `hooks.json` has no matcher support, so Codex keeps a generic body.
- **Replacing `terminal-notifier`.** Only if Phase 2 proves `-execute` dead.
