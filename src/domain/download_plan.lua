-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local DownloadPath = require("domain/download_path")

local DownloadPlan = {}

-- Map each book in a batch to a UNIQUE destination path, disambiguating collisions
-- (same/absent numberSort -> same name) with the book id; otherwise the second file
-- would be silently skipped as "already exists". Pure (testable without download I/O).
-- Returns a list of { book = <book>, dest = <absolute path> }.
function DownloadPlan.resolve(books, root)
  local used, plan = {}, {}
  for _, b in ipairs(books) do
    local dest = DownloadPath.forBook(root, b.seriesTitle, b.sort)
    if used[dest] then
      dest = DownloadPath.forBook(root, b.seriesTitle, b.sort, b.id)
    end
    used[dest] = true
    plan[#plan + 1] = { book = b, dest = dest }
  end
  return plan
end

return DownloadPlan
