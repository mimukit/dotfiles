# QA Plan: agent-hook notification context and click-to-focus

_Generated 2026-08-22 · against `9598896` · covers the Claude Code and Codex desktop toast produced by `~/.local/bin/agent-hook`_

## Summary

- The hook now names the repo and branch in the toast, states why the agent stopped, and focuses the pane that sent the toast when you click it.
- Working means three things. The toast names the right repo and branch. The reason text matches what the agent actually did. A click puts the cursor in the pane that fired it.

## Overall result

_Tick one when you finish the run._

- [ ] Pass: every case passed
- [ ] Fail: at least one case failed
- [ ] Partial: cases were skipped or not reached

## Environment

True for the whole plan. Do this once, before Scenario 1.

- Branch `main` at commit `9598896`.
- macOS 26.6.2. iTerm2 is the terminal. tmux runs the sessions.
- `terminal-notifier` is on `PATH`. `alerter` is not installed and this plan does not need it.
- macOS grants notification permission to the notifier. Turn off Do Not Disturb, or the banners never appear.

Confirm the deployed hook matches the commit:

```sh
diff -q ~/.local/bin/agent-hook ~/.local/share/chezmoi/private_dot_local/bin/executable_agent-hook && echo identical
```

Confirm Claude Code loaded the five matcher entries:

```sh
jq -r '.hooks.Notification[] | .matcher // "(none)"' ~/.claude/settings.json
```

Clear old banners so the run starts clean:

```sh
terminal-notifier -remove ALL
```

- [ ] Environment ready

## Test cases at a glance

Priority legend: 🔴 Critical · 🟡 Normal · 🟢 Low

| # | Scenario | Test case | Priority |
|------|----------|-----------|----------|
| TC-1.1 | 1: Claude Code in a tmux pane, iTerm2 | The banner carries the repo, the branch and a reason | 🔴 Critical |
| TC-1.2 | 1: Claude Code in a tmux pane, iTerm2 | A click lands in the pane that sent the banner | 🔴 Critical |
| TC-1.3 | 1: Claude Code in a tmux pane, iTerm2 | The reason text changes with the notification type | 🟡 Normal |
| TC-1.4 | 1: Claude Code in a tmux pane, iTerm2 | One session holds one banner, not a stack | 🟡 Normal |
| TC-1.5 | 1: Claude Code in a tmux pane, iTerm2 | The Stop banner quotes the agent's closing line | 🟡 Normal |
| TC-1.6 | 1: Claude Code in a tmux pane, iTerm2 | rm-guard and the port cleanup still run | 🔴 Critical |
| TC-2.1 | 2: Claude Code in bare iTerm2, no tmux | A click selects the right iTerm2 tab | 🟡 Normal |
| TC-3.1 | 3: Claude Code inside Paseo or Orca | The hook sends no banner | 🔴 Critical |
| TC-4.1 | 4: Codex CLI in a tmux pane | Codex gets a titled banner with a click target | 🟢 Low |

## Scenario 1: Claude Code in a tmux pane, iTerm2

**Setup.** Run once, for every case in this scenario.

1. Open iTerm2. Attach to tmux.
2. Create two windows in one session. Put a git repo in window 1 and a different repo in window 2.
3. Start Claude Code in window 1.
4. Confirm the pane exports the variables the hook reads. Run this inside the Claude Code pane, in shell mode:

```sh
echo "TMUX=${TMUX:-UNSET} TMUX_PANE=${TMUX_PANE:-UNSET} TERM_PROGRAM=${TERM_PROGRAM:-UNSET}"
```

- [ ] Setup complete

### TC-1.1: The banner carries the repo, the branch and a reason · 🔴 Critical

**Goal.** The toast identifies which checkout woke you, without you opening any window.

**Steps**

1. Ask Claude Code to do something that needs permission. Switch to another application at once. Wait about six seconds.
   - [ ] The banner reads correctly at a glance
     - title: `Claude Code`
     - subtitle: the repo directory name, then ` · `, then the current branch
     - body: `Needs permission`
2. Confirm the branch is the live one. Run this in the repo:

```sh
git symbolic-ref --short HEAD
```

   - [ ] The branch in the banner matches this output
3. Start Claude Code in a directory that is not a git checkout. Trigger a permission prompt again.
   - [ ] The subtitle shows the directory name alone, with no separator and no branch

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _what actually happened on a fail; why it was skipped_

### TC-1.2: A click lands in the pane that sent the banner · 🔴 Critical

**Goal.** `terminal-notifier -execute` fires on macOS 26, and the tmux target it carries is correct. This case is the one unproven link in the feature.

**Steps**

1. Start Claude Code in tmux window 1. Trigger a permission prompt.
2. Switch tmux to window 2. Switch macOS focus to another application. Wait for the banner.
3. Click the body of the banner. Do not click a button.
   - [ ] macOS raises iTerm2
   - [ ] tmux shows window 1, and the cursor sits in the Claude Code pane
4. Repeat with two tmux sessions. Start Claude Code in session A. Attach the client to session B. Trigger a prompt, then click the banner.
   - [ ] tmux switches the client to session A
5. If step 3 raises iTerm2 but does not change the window, run the generated command by hand to separate the two failures:

```sh
tmux switch-client -t <session> \; select-window -t <session>:<window> \; select-pane -t <session>:<window>.<pane>
```

   - [ ] The command alone moves tmux to the right pane

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _If step 3 does nothing at all, `-execute` is dead on this macOS build. Install `alerter` and swap the `-execute` branch of `feat_notify` for `@CONTENTCLICKED`. If step 5 works but step 3 does not, the fault is `-execute`, not the tmux target._

### TC-1.3: The reason text changes with the notification type · 🟡 Normal

**Goal.** The five matcher entries route to five different bodies, and no event produces two banners.

**Steps**

1. Trigger a permission prompt. Switch away. Wait about six seconds.
   - [ ] The body reads `Needs permission`
2. Let Claude Code finish a reply. Do not type. Wait about 60 seconds.
   - [ ] The body reads `Waiting for you`
   - [ ] Notification Center holds one banner for this event, not two
3. Read the delivery log:

```sh
terminal-notifier -list ALL
```

   - [ ] Each event appears once, with a group ID that is not `(null)`

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _A duplicated row means an empty matcher slipped back into `~/.claude/settings.json`._

### TC-1.4: One session holds one banner, not a stack · 🟡 Normal

**Goal.** The `-group` flag keyed on `session_id` replaces a stale banner instead of adding a row.

**Steps**

1. Trigger a permission prompt in one Claude Code session. Answer it. Let the turn finish.
2. Open Notification Center.
   - [ ] One banner represents this session, and it shows the newest message
3. Start a second Claude Code session in another repo. Trigger a prompt there too.
   - [ ] Two banners appear, one per session, each with its own subtitle

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _what actually happened on a fail; why it was skipped_

### TC-1.5: The Stop banner quotes the agent's closing line · 🟡 Normal

**Goal.** `last_assistant_message` reaches the banner, flattened and cut, instead of the old fixed string.

**Steps**

1. Ask Claude Code a question with a short answer. Switch away before it finishes.
   - [ ] The body shows the agent's closing text, not `Task completed`
2. Ask Claude Code a question with a long answer. Switch away.
   - [ ] The body ends in `...` and stops at a readable point
   - [ ] The body sits on one line, with no line breaks and no doubled spaces

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _Judge whether the 80-character cut reads well. Report a body that stops mid-word or mid-clause often enough to annoy you._

### TC-1.6: rm-guard and the port cleanup still run · 🔴 Critical

**Goal.** The rewrite touched one shared script, so the two features that share it still work.

**Steps**

1. Ask Claude Code to delete a file that is not tracked by git and is not in a temp directory.
   - [ ] rm-guard prompts you, and the prompt names the target
2. Ask Claude Code to delete a git-tracked file.
   - [ ] rm-guard passes it through without a prompt
3. Start a dev server inside an Orca worktree under `~/orca/workspaces/`. Let the Claude Code turn end.
   - [ ] The port cleanup stops the server

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _Skip step 3 if no Orca worktree is available. Record that as the reason._

**Reset.** Run after every case above, before moving to Scenario 2.

```sh
terminal-notifier -remove ALL
```

## Scenario 2: Claude Code in bare iTerm2, no tmux

**Setup.** Run once, for every case in this scenario.

1. Open iTerm2. Do not attach to tmux.
2. Open three tabs. Start Claude Code in tab 2.
3. Confirm the session exports an iTerm2 identity. Run this in tab 2:

```sh
echo "ITERM_SESSION_ID=${ITERM_SESSION_ID:-UNSET} TMUX=${TMUX:-UNSET}"
```

- [ ] Setup complete

### TC-2.1: A click selects the right iTerm2 tab · 🟡 Normal

**Goal.** The AppleScript branch finds the session by its UUID and selects that tab.

**Steps**

1. Trigger a permission prompt in tab 2. Switch to tab 3. Switch macOS focus away.
2. Click the banner.
   - [ ] macOS raises iTerm2
   - [ ] iTerm2 shows tab 2, not tab 3
3. Repeat with Claude Code running in a second iTerm2 window.
   - [ ] iTerm2 raises the correct window as well as the correct tab

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _This branch is the fallback for a session outside tmux. A failure here matters less than TC-1.2. If iTerm2 raises but the tab does not change, the UUID split of `ITERM_SESSION_ID` is wrong._

**Reset.** Run after the case above, before moving to Scenario 3.

```sh
terminal-notifier -remove ALL
```

## Scenario 3: Claude Code inside Paseo or Orca

**Setup.** Run once, for every case in this scenario.

1. Open Paseo, or open Orca.
2. Start a Claude Code session from inside the application, not from a terminal.

- [ ] Setup complete

### TC-3.1: The hook sends no banner · 🔴 Critical

**Goal.** The suppression list still stops a duplicate banner where the application already shows agent state.

**Steps**

1. Trigger a permission prompt inside the Paseo or Orca session. Switch macOS focus away. Wait about ten seconds.
   - [ ] The application shows its own agent state indicator
   - [ ] No `Claude Code` banner appears from `terminal-notifier`
2. Read the delivery log:

```sh
terminal-notifier -list ALL
```

   - [ ] No new row appeared for this session

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _A banner here means a suppression variable changed name. Check `NOTIFY_SUPPRESS_VARS` in the hook against the variables the application sets._

**Reset.** Run after the case above, before moving to Scenario 4.

```sh
terminal-notifier -remove ALL
```

## Scenario 4: Codex CLI in a tmux pane

**Setup.** Run once, for every case in this scenario.

1. Open iTerm2. Attach to tmux.
2. Start Codex CLI in a git repo.

- [ ] Setup complete

### TC-4.1: Codex gets a titled banner with a click target · 🟢 Low

**Goal.** The shared dispatcher serves Codex too, and Codex keeps working without matcher support.

**Steps**

1. Trigger a Codex notification. Switch away.
   - [ ] The title reads `Codex`, and the subtitle shows the repo and branch
   - [ ] The body reads `Awaiting your input`, which is the generic text Codex always gets
2. Click the banner.
   - [ ] tmux moves to the Codex pane
3. Confirm Codex Computer Use still works.
   - [ ] The `notify` key in `~/.codex/config.toml` still points at `SkyComputerUseClient`

**Result**

- [ ] Pass
- [ ] Fail
- [ ] Skipped

**Notes.** _Codex hook entries carry no matcher, so a specific reason is out of scope here._

**Reset.**

```sh
terminal-notifier -remove ALL
```

## Automated verification (by AI agent)

_Checks the agent ran itself. No action needed from the tester; listed here for context and sign-off._

Commands run:

```sh
bash -n private_dot_local/bin/executable_agent-hook && shellcheck -s bash private_dot_local/bin/executable_agent-hook && jq -e . .chezmoitemplates/claude-settings.json
```

```sh
chezmoi diff ~/.claude/settings.json | grep -c "^-[^-]"
```

```sh
chezmoi cat ~/.claude/settings.json | jq -r '[.. | objects | select(has("command")) | .command] | map(if test("orca") then "orca" elif test("paseo|PASEO") then "paseo" elif test("herdr") then "herdr" elif test("local/bin/agent-hook") then "ours" else "other" end) | group_by(.) | map({(.[0]): length}) | add'
```

```sh
sh -c 'tmux switch-client -t system_updates \; select-window -t system_updates:1 \; select-pane -t system_updates:1.1'
```

```sh
osacompile -o /tmp/nk.scpt -e 'tell application "iTerm2"' -e 'activate' -e 'repeat with w in windows' -e 'repeat with t in tabs of w' -e 'repeat with s in sessions of t' -e 'if id of s is "9C1D-4E2F" then' -e 'select w' -e 'select t' -e 'select s' -e 'end if' -e 'end repeat' -e 'end repeat' -e 'end repeat' -e 'end tell'
```

- ✅ `bash -n`, `shellcheck -s bash`, `jq -e` → syntax clean, lint clean with no warnings, template is valid JSON.
- ✅ `chezmoi diff` → 0 removed lines. The merge only adds.
- ✅ Vendor hook survival after apply → `orca: 11`, `paseo: 5`, `herdr: 1`, `ours: 7`. No vendor entry was dropped.
- ✅ Dispatcher argument build, run against a fake `terminal-notifier` → `permission_prompt` produced `Needs permission`, `idle_prompt` produced `Waiting for you`, Codex produced `Awaiting your input`, and every case carried `-subtitle 'chezmoi · main'` and `-group sess-abc123`.
- ✅ tmux target resolution against the live server → pane `%20` resolved to `default:1.1`, pane `%1` resolved to `system_updates:1.1`.
- ✅ tmux command chain → exit 0. tmux accepts the generated syntax.
- ✅ AppleScript → `osacompile` accepted the 14-line script. The syntax is valid.
- ✅ Suppression → with `PASEO_AGENT_ID` set, `feat_notify` returned before calling the notifier.
- ✅ Real end-to-end toast through the deployed hook → Notification Center recorded `e2e-check | Claude Code | chezmoi · main | End to end check of the new notification path.`
- ✅ `terminal-notifier -remove ALL` → exit 0. The reset command in this plan works.

## Not covered / needs human judgment

- **Whether `-execute` fires at all on macOS 26.6.2.** This is the reason TC-1.2 is critical. The agent proved the command string is correct and that tmux accepts it. Only a human click proves macOS runs it.
- **Whether the AppleScript selects the right tab.** `osacompile` proves the syntax, not the behaviour. Running it needs a live iTerm2 with a matching session UUID.
- **Whether the 80-character cut reads well.** TC-1.5 asks for a judgment, not a measurement.
- **Concurrency.** Two agents finishing at the same moment are not tested. The `-group` key is the session id, so they should not collide, but no case forces the race.
- **Performance.** Not covered, and not a concern. The hook adds three `tmux display-message` calls and one `git symbolic-ref`, all local, against a 10-second budget.
- **Accessibility and compatibility.** Not applicable. The feature has no UI beyond a macOS banner, and it is macOS-only by construction.
- **A tenth notification type.** If a future Claude Code release adds a notification type, it matches none of the five entries and produces no banner. No case can test a type that does not exist yet.
