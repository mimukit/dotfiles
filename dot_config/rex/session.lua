-- Helpers that custom actions share. Call them only from inside an action:
-- server calls do not work while the config file loads.
--
-- Each helper takes an optional server, from rex.server(label). Without
-- one, the call goes to this Mac's server.

local M = {}

-- Return the ID of the session with this label, or nil if it does not exist.
function M.find(label, server)
  local result, err = (server or rex).call("session.list", {})
  if not result then
    error("session.list failed: " .. tostring(err))
  end
  for _, s in ipairs(result.sessions or {}) do
    if s.label == label then
      return s.session_id
    end
  end
  return nil
end

-- Return the ID of the session with this label, and whether this call
-- created it. Create the session with one window when it does not exist.
function M.ensure(label, window, server)
  local id = M.find(label, server)
  if id then
    return id, false
  end
  local result, err = (server or rex).call("session.create", {
    label = label,
    initial_windows = { window },
  })
  if not result then
    error("session.create failed: " .. tostring(err))
  end
  return result.session_id, true
end

-- Switch the app to the session with this label, created as in ensure.
-- This works only for a session on this Mac's server: the app's
-- session.select looks the ID up here. Returns the same as ensure.
function M.open(label, window)
  local id, created = M.ensure(label, window)
  rex.client.queue("session.select", { session_id = id })
  return id, created
end

return M
