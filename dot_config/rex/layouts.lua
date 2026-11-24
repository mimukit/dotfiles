-- Session layouts that replace the tmuxinator projects.

local session = require("session")

-- A shell that types a command at its first prompt, so zsh aliases work
-- and the shell stays open after the command, as in tmuxinator.
local function shell(label, input, cwd)
  return rex.layout.block{
    flavor = "com.superlogical.terminal.shell",
    label = label,
    options = {
      cwd = cwd,
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
    local home = os.getenv("HOME")
    session.open("system_updates", {
      window_label = "system_updates",
      layout = rex.layout.vertical(1 / 3,
        shell("brew_update", "brewupx", home),
        rex.layout.vertical(1 / 2,
          shell("topgrade", "topgrade", home),
          shell("misc", "atuin sync; exit", home))),
    })
  end,
}

rex.bind("ctrl+b>shift+u", "upx")

local devaloy_hosts = { "devaloy-upbox", "devaloy-ovh", "devaloy-metal" }

rex.action{
  name = "devup",
  title = "Devaloy Updates",
  description = "Open an update session on each Devaloy host.",
  category = "Sessions",
  keywords = "devup devaloy update remote hosts",
  run = function()
    local failures = {}
    for _, host in ipairs(devaloy_hosts) do
      local ok, err = pcall(function()
        session.ensure("devaloy_update", {
          window_label = "devaloy_update",
          layout = shell("devaloy_update", "devaloy update"),
        }, rex.server(host))
      end)
      if not ok then
        failures[#failures + 1] = host .. ": " .. tostring(err)
      end
    end
    if #failures > 0 then
      error(table.concat(failures, "\n"), 0)
    end
  end,
}

rex.bind("ctrl+b>shift+d", "devup")
