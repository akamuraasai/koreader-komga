-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local ChapterName = {}

-- Zero-padded .cbz filename from a chapter's numeric `sort`: integers -> "0001.cbz",
-- decimals -> "0016.5.cbz". The integer part uses string.format("%04d") so it's
-- identical on LuaJIT and host Lua; fractional names inherit tostring(float) precision.
function ChapterName.forSort(sort)
  sort = sort or 0
  local int = math.floor(sort)
  if sort == int then
    return string.format("%04d.cbz", int)
  end
  local frac = tostring(sort):match("%.(%d+)$") or ""
  return string.format("%04d", int) .. "." .. frac .. ".cbz"
end

return ChapterName
