-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local Selection = {}

local function bySort(a, b) return a.sort < b.sort end

function Selection.unreadIds(books)
  local ids = {}
  for _, b in ipairs(books) do
    if not b.completed then ids[#ids + 1] = b.id end
  end
  return ids
end

function Selection.nextNUnread(books, n)
  local sorted = {}
  for _, b in ipairs(books) do sorted[#sorted + 1] = b end
  table.sort(sorted, bySort)
  local lastReadSort
  for _, b in ipairs(sorted) do
    if b.completed then lastReadSort = b.sort end
  end
  local ids = {}
  for _, b in ipairs(sorted) do
    if #ids >= n then break end
    if not b.completed and (lastReadSort == nil or b.sort > lastReadSort) then
      ids[#ids + 1] = b.id
    end
  end
  return ids
end

return Selection
