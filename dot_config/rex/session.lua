-- Helpers that custom actions share. Call them only from inside an action:
-- server calls do not work while the config file loads.

local M = {}

-- Return the ID of the session with this label, or nil.
function M.find(label)
  local result, err = rex.call("session.list", {})
  if not result then
    rex.log("warn", "session.list failed: " .. tostring(err))
    return nil
  end
  for _, s in ipairs(result.sessions or {}) do
    if s.label == label then
      return s.session_id
    end
  end
  return nil
end

-- Switch the app to the session with this label. Create the session with
-- one window first when it does not exist. Returns the session ID and
-- whether this call created it.
function M.open(label, window)
  local id = M.find(label)
  local created = false
  if not id then
    local result, err = rex.call("session.create", {
      label = label,
      initial_windows = { window },
    })
    if not result then
      error("session.create failed: " .. tostring(err))
    end
    id = result.session_id
    created = true
  end
  rex.client.queue("session.select", { session_id = id })
  return id, created
end

return M
