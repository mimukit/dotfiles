-- Session layouts that replace the tmuxinator projects.

local session = require("session")

-- A shell that types a command at its first prompt, so zsh aliases work
-- and the shell stays open after the command, as in tmuxinator.
local function shell(label, input)
  return rex.layout.block{
    flavor = "com.superlogical.terminal.shell",
    label = label,
    options = {
      cwd = os.getenv("HOME"),
      initial_input = input .. "\n",
    },
  }
end

-- upx: the old tmuxinator "upx" project (system_updates), three panes
-- stacked top to bottom. Ctrl+B Shift+U, the palette, or `rex do upx`.
rex.action{
  name = "upx",
  title = "System Updates",
  description = "Run brew, topgrade, and atuin sync in three stacked panes.",
  category = "Sessions",
  keywords = "upx update upgrade brew topgrade atuin tmuxinator",
  run = function(ctx, args)
    session.open("system_updates", {
      window_label = "system_updates",
      layout = rex.layout.vertical(1 / 3,
        shell("brew_update", "brewupx"),
        rex.layout.vertical(1 / 2,
          shell("topgrade", "topgrade"),
          shell("misc", "atuin sync; exit"))),
    })
  end,
}

rex.bind("ctrl+b>shift+u", "upx")
