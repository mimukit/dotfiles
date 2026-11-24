-- Project picker: Ctrl+B u, or "Open Project…" in the command palette.
--
-- Lists the 40 most used zoxide folders and every folder directly in
-- ~/Projects. Picking one switches to the session named after the folder,
-- or creates that session with a shell in the folder.

local session = require("session")

local HOME = os.getenv("HOME") or ""
local ZOXIDE_LIMIT = 40

-- The Rex server starts with PATH=/usr/bin:/bin:/usr/sbin:/sbin, which has
-- no Homebrew. rex.exec looks a program up in the PATH given here.
local EXEC_OPTS = {
  timeout = 5,
  env = { PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" },
}

local function basename(path)
  return path:match("([^/]+)/*$")
end

local function tilde(path)
  if HOME ~= "" and path:sub(1, #HOME) == HOME then
    return "~" .. path:sub(#HOME + 1)
  end
  return path
end

local function lines(result)
  local out = {}
  if result and result.ok then
    for line in result.stdout:gmatch("[^\n]+") do
      out[#out + 1] = line
    end
  end
  return out
end

local function project_items()
  local items, seen = {}, {}

  local function add(path)
    local name = basename(path)
    if not name or path == HOME or seen[path] then
      return
    end
    seen[path] = true
    items[#items + 1] = {
      id = path,
      title = name,
      subtitle = tilde(path),
      icon = "folder",
    }
  end

  local zoxide = rex.exec({ "zoxide", "query", "--list" }, EXEC_OPTS)
  local count = 0
  for _, path in ipairs(lines(zoxide)) do
    if count >= ZOXIDE_LIMIT then
      break
    end
    add(path)
    count = count + 1
  end

  local projects = rex.exec({
    "find", HOME .. "/Projects",
    "-mindepth", "1", "-maxdepth", "1",
    "-type", "d", "-not", "-name", ".*",
  }, EXEC_OPTS)
  local dirs = lines(projects)
  table.sort(dirs)
  for _, path in ipairs(dirs) do
    add(path)
  end

  return items
end

rex.action{
  name = "project_open",
  title = "Open Project…",
  description = "Switch to a project's session, or create it in the project folder.",
  category = "Sessions",
  keywords = "project session zoxide sesh tmuxinator",
  run = function(ctx, args)
    local items = project_items()
    if #items == 0 then
      rex.log("warn", "project_open: zoxide and ~/Projects gave no folders")
      return
    end

    local dir = rex.ui.pick{
      title = "Open project",
      placeholder = "Filter projects",
      items = items,
    }
    if dir == nil then
      return
    end

    session.open(basename(dir), {
      layout = rex.layout.block{
        flavor = "com.superlogical.terminal.shell",
        options = { cwd = dir },
      },
    })
  end,
}

rex.bind("ctrl+b>u", "project_open")
