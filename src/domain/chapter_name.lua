-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local ChapterName = {}

-- Zero-padded .cbz filename from a chapter's numeric `sort`: integers -> "0001.cbz",
-- decimals -> "0016.5.cbz", negatives -> "-0002.cbz". The integer part uses
-- string.format("%04d") so it's identical on LuaJIT and host Lua; fractional names
-- inherit tostring(float) precision.
function ChapterName.forSort(sort)
  sort = sort or 0
  local sign = sort < 0 and "-" or ""
  local abs = math.abs(sort)
  local int = math.floor(abs)
  if abs == int then
    return sign .. string.format("%04d.cbz", int)
  end
  local frac = tostring(abs):match("%.(%d+)$") or ""
  return sign .. string.format("%04d", int) .. "." .. frac .. ".cbz"
end

return ChapterName
