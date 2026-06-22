-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local PathUtil = {}

-- Illegal on FAT32/exFAT (Kobo) plus control chars.
local ILLEGAL = '[\\/:%*%?"<>|%c]'

function PathUtil.sanitizeComponent(name)
  if not name or name == "" then return "_" end
  local out = name:gsub(ILLEGAL, " ")
  out = out:gsub("%s+", " ")
  out = out:gsub("^%s+", "")
  out = out:gsub("[%.%s]+$", "")
  if out == "" then return "_" end
  return out
end

return PathUtil
