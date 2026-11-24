-- Rex configuration. Docs: https://www.superlogical.com/rex/docs/customize/config
--
-- This file holds key bindings only. Theme, font, padding and other looks
-- live in Rex Settings (Cmd+,), not here.
--
-- Rex keeps its own Cmd shortcuts (Cmd+T, Cmd+D, Cmd+K, ...). The Ctrl+B
-- prefix below copies ~/.config/tmux/tmux.conf.
--
-- Apply changes:  rex config check && rex config reload  (or Ctrl+B r)
-- List actions:   rex -C <client> actions

local prefix = "ctrl+b"

local function tmux(key, action, args)
  rex.bind(prefix .. ">" .. key, action, args)
end

-- Press Ctrl+B twice to send one Ctrl+B to the program.
tmux("ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- Splits (% and " on a US layout)
tmux("shift+5", "pane.split", { direction = "right" })
tmux("shift+'", "pane.split", { direction = "down" })

-- Tabs (tmux windows)
tmux("c", "client.tab.new")
tmux("n", "client.tab.next")
tmux("p", "client.tab.previous")
tmux(",", "client.tab.rename")
tmux("shift+7", "client.tab.close") -- &
for i = 1, 9 do
  tmux(tostring(i), "client.tab.goto", { index = i })
end

-- Sessions
tmux("s", "session.switch")
tmux("shift+4", "session.rename") -- $

-- Panes
tmux("z", "pane.zoom")
tmux("x", "pane.close")
tmux("o", "pane.focus_next")
tmux("left", "pane.focus.left")
tmux("right", "pane.focus.right")
tmux("up", "pane.focus.up")
tmux("down", "pane.focus.down")
tmux("[", "pane.copy_mode.enter")

-- Resize by 5 cells, as in tmux.conf
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  tmux("ctrl+" .. dir, "pane.resize", { direction = dir, amount = 5 })
end

-- Clear the screen and scrollback
tmux("k", "com.superlogical.terminal.clear")

-- Reload this file
tmux("r", "client.config.reload")

-- Ctrl+X closes the pane without the prefix, as in tmux.conf.
-- This hides Ctrl+X from zsh (Ctrl+X Ctrl+E) and nano. Delete the line to free it.
rex.bind("ctrl+x", "pane.close")

-- Resize mode: Ctrl+B Shift+R, then arrows. Escape or Enter leaves it.
rex.mode("resize", { exclusive = true })
tmux("shift+r", "client.mode.enter", { name = "resize" })
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  rex.bind("resize/" .. dir, "pane.resize", { direction = dir })
  rex.bind("resize/shift+" .. dir, "pane.resize", { direction = dir, amount = 15 })
end
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")

-- Custom actions. Ctrl+B u opens the project picker (was the sesh picker).
-- Ctrl+B Shift+U opens the upx system update layout.
-- Ctrl+B w opens a git worktree on devaloy-metal.
require("projects")
require("layouts")
require("worktrees")

-- Remote hosts (devaloy-metal) live in Settings > Remote Hosts, not here:
-- the app does not show rex.host entries. Add them by hand on a new Mac.
