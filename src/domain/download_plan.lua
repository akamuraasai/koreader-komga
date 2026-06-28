-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local DownloadPath = require("domain/download_path")

local DownloadPlan = {}

local function keyOf(b) return tostring(b.seriesTitle) .. "\0" .. tostring(b.sort) end

-- Map each book to a UNIQUE destination + its series dir. Any (seriesTitle, sort) key
-- shared by more than one book in `books` makes ALL its books id-suffixed, so a book's
-- on-disk name depends only on its identity within a fixed set -- never on iteration
-- order. Returns { { book, dest, dir }, ... } in input order. Pure.
function DownloadPlan.resolve(books, root)
  local counts = {}
  for _, b in ipairs(books) do
    local k = keyOf(b); counts[k] = (counts[k] or 0) + 1
  end
  local plan = {}
  for _, b in ipairs(books) do
    local suffix = counts[keyOf(b)] > 1 and b.id or nil
    plan[#plan + 1] = {
      book = b,
      dest = DownloadPath.forBook(root, b.seriesTitle, b.sort, suffix),
      dir = DownloadPath.dirFor(root, b.seriesTitle),
    }
  end
  return plan
end

return DownloadPlan
