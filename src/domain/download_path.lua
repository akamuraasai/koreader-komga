-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local PathUtil = require("common/pathutil")
local ChapterName = require("domain/chapter_name")
local NameTemplate = require("domain/name_template")

local DownloadPath = {}

-- Sanitized series folder: <root>/<sanitized series>; the root itself for flat naming.
function DownloadPath.dirFor(root, seriesTitle, naming)
  if naming and naming.flat then return root end
  return root .. "/" .. PathUtil.sanitizeComponent(seriesTitle)
end

-- Absolute path a chapter downloads to: <dir>/<name>.cbz, name from the optional
-- naming { template, flat, title } (default "{number}", the historical NNNN name).
-- Shared by the downloader and the picker's "already downloaded" marker. An optional
-- `suffix` (e.g. a book id) disambiguates chapters that would otherwise share a name.
function DownloadPath.forBook(root, seriesTitle, sort, suffix, naming)
  local name
  if naming and naming.template then
    name = NameTemplate.render(naming.template, {
      series = seriesTitle, title = naming.title, number = ChapterName.numberFor(sort),
    }) .. ".cbz"
  else
    name = ChapterName.forSort(sort)
  end
  if suffix and suffix ~= "" then
    name = name:gsub("%.cbz$", "_" .. PathUtil.sanitizeComponent(suffix) .. ".cbz")
  end
  return DownloadPath.dirFor(root, seriesTitle, naming) .. "/" .. name
end

return DownloadPath
