-- Worktree picker for devaloy-metal: Ctrl+B w, or "Open Remote Worktree…"
-- in the command palette.
--
-- Lists every git worktree of the repos in ~/projects on the box, linked
-- worktrees (T3 Code and gitkit put them in ~/worktrees) first. Picking one
-- creates the session <project>/<worktree> on the box, with a shell in the
-- worktree, unless it exists. Click it in the sidebar under the host.
--
-- The picker does not switch to the session. The app's session.select finds
-- only sessions on this Mac, and asking the box to switch the app
-- (client.perform) needs Remote Control on, which stays off.
--
-- The box must be in Settings > Remote Hosts with this label.

local session = require("session")

local HOST = "devaloy-metal"

-- One ssh call lists all worktrees. Each repo's porcelain output is a run
-- of blocks with a blank line between them.
local LIST_SCRIPT = [[
for g in "$HOME"/projects/*/.git; do
  [ -d "$g" ] || continue
  git -C "${g%/.git}" worktree list --porcelain
  echo
done
]]

local function basename(path)
  return path:match("([^/]+)/*$")
end

-- Parse `git worktree list --porcelain` into { path, branch, main } rows.
-- The first block of each repo is its main checkout.
local function parse(stdout)
  local rows, row, first = {}, nil, true
  local function flush()
    if row and not row.bare and not row.prunable then
      rows[#rows + 1] = row
    end
    row = nil
  end
  for line in (stdout .. "\n"):gmatch("([^\n]*)\n") do
    local key, value = line:match("^(%S+)%s?(.*)$")
    if key == nil then
      flush()
    elseif key == "worktree" then
      flush()
      row = { path = value, main = value:match("^.*/projects/[^/]+$") ~= nil }
    elseif row and key == "branch" then
      row.branch = value:gsub("^refs/heads/", "")
    elseif row and key == "detached" then
      row.branch = "detached"
    elseif row and (key == "bare" or key == "prunable") then
      row[key] = true
    end
  end
  flush()
  return rows
end

-- Session label: "saasaloy/issue-335-..." for a linked worktree,
-- "saasaloy" for a main checkout. T3 Code names its worktrees
-- t3-<hash>, so those take the branch name in place of the folder name.
local function label_for(row)
  local project = row.path:match("/worktrees/([^/]+)/[^/]+$")
  local name = basename(row.path)
  if row.main or not project then
    return name
  end
  if name:match("^t3%-") and row.branch and row.branch ~= "detached" then
    name = row.branch
  end
  return project .. "/" .. name
end

local function list_worktrees()
  local result = rex.exec(
    { "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", HOST, LIST_SCRIPT },
    { timeout = 15 }
  )
  if not result or not result.ok then
    error("listing worktrees on " .. HOST .. " failed: "
      .. tostring(result and result.stderr))
  end
  local rows = parse(result.stdout)
  table.sort(rows, function(a, b)
    if a.main ~= b.main then
      return not a.main
    end
    return label_for(a) < label_for(b)
  end)
  return rows
end

rex.action{
  name = "remote_worktree_open",
  title = "Open Remote Worktree…",
  description = "Switch to a session in a git worktree on " .. HOST .. ", or create it.",
  category = "Sessions",
  keywords = "worktree git remote devaloy metal t3 session",
  run = function(ctx, args)
    local server = rex.server(HOST)

    local open = {}
    local sessions = server.call("session.list", {})
    for _, s in ipairs(sessions and sessions.sessions or {}) do
      open[s.label] = true
    end

    -- The picker has a fixed width, so each row keeps its text short: the
    -- worktree name as the title, the project (and the branch when it
    -- differs from the name) below it, and "open" at the far end when a
    -- session exists. Filtering still matches the title.
    local items, by_id = {}, {}
    for _, row in ipairs(list_worktrees()) do
      local label = label_for(row)
      local project, name = label:match("^([^/]+)/(.+)$")
      if not project then
        project, name = "main checkout", label
      end
      local subtitle = project
      if row.branch and row.branch ~= name then
        subtitle = subtitle .. "  ·  " .. row.branch
      end
      items[#items + 1] = {
        id = row.path,
        title = name,
        subtitle = subtitle,
        icon = row.main and "folder" or "branch",
        detail = open[label] and "open" or nil,
      }
      by_id[row.path] = label
    end

    local path = rex.ui.pick{
      title = "Open worktree on " .. HOST,
      placeholder = "Filter worktrees",
      items = items,
    }
    if path == nil then
      return
    end

    local _, created = session.ensure(by_id[path], {
      layout = rex.layout.block{
        flavor = "com.superlogical.terminal.shell",
        options = { cwd = path },
      },
    }, server)
    rex.log("info", string.format("remote_worktree_open: %s %s on %s",
      created and "created" or "found", by_id[path], HOST))
  end,
}

rex.bind("ctrl+b>w", "remote_worktree_open")
