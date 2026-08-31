-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local PathUtil = require("common/pathutil")

local NameTemplate = {}

local SEP = "[%-_%. ]"
local KNOWN = { series = true, title = true, number = true }

-- Returns true, or false + kind ("unknown"|"missing_number"|"missing_series") + detail.
function NameTemplate.validate(template, opts)
  for key in template:gmatch("{(%w*)}") do
    if not KNOWN[key] then return false, "unknown", key end
  end
  if not template:find("{number}", 1, true) then return false, "missing_number" end
  if opts and opts.flat and not template:find("{series}", 1, true) then
    return false, "missing_series"
  end
  return true
end

function NameTemplate.render(template, ctx)
  local name = template:gsub("{(%w+)}", function(key)
    local v = ctx[key]
    if v == nil or v == "" then return "\1" end
    return v
  end)
  -- An empty value eats the separator before it, or the one after when at the start.
  name = name:gsub(SEP .. "\1", ""):gsub("\1" .. SEP .. "?", "")
  if name:gsub(SEP, "") == "" then name = ctx.number or "" end
  return PathUtil.sanitizeComponent(name)
end

return NameTemplate
