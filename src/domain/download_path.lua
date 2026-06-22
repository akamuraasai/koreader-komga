-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local PathUtil = require("common/pathutil")
local ChapterName = require("domain/chapter_name")

local DownloadPath = {}

-- Absolute path a chapter downloads to: <root>/<sanitized series>/<NNNN.cbz>.
-- Shared by the downloader and the picker's "already downloaded" marker. An optional
-- `suffix` (e.g. a book id) disambiguates chapters that would otherwise share a name.
function DownloadPath.forBook(root, seriesTitle, sort, suffix)
  local name = ChapterName.forSort(sort)
  if suffix and suffix ~= "" then
    name = name:gsub("%.cbz$", "_" .. PathUtil.sanitizeComponent(suffix) .. ".cbz")
  end
  return root .. "/" .. PathUtil.sanitizeComponent(seriesTitle) .. "/" .. name
end

return DownloadPath
