-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local PathUtil = require("common/pathutil")
local DownloadPlan = require("domain/download_plan")
local _ = require("gettext")
local T = require("ffi/util").template

local Downloader = {}

local function ensureDir(path)
  if lfs.attributes(path, "mode") ~= "directory" then util.makePath(path) end
end

-- books: flat list of { id, seriesTitle, number, sort }. Each chapter routes to its
-- OWN series folder, so a mixed-series selection (Current Reading / Deck / Last
-- Updated) downloads correctly, and a single-series selection behaves as before.
function Downloader.run(api, dest_root, books)
  Trapper:wrap(function()
    local ok_count, skip_count, fail_count, stopped = 0, 0, 0, false
    local ensured = {}
    -- Resolve unique destinations up front so two chapters that map to the same name
    -- (duplicate/absent numberSort) don't silently skip each other.
    local plan = DownloadPlan.resolve(books, dest_root)
    for i, item in ipairs(plan) do
      local b, dest = item.book, item.dest
      local dir = dest_root .. "/" .. PathUtil.sanitizeComponent(b.seriesTitle)
      if not ensured[dir] then ensureDir(dir); ensured[dir] = true end
      if lfs.attributes(dest, "mode") == "file" then
        skip_count = skip_count + 1
      else
        -- Trapper:info returns false if the user dismissed the popup -> stop between chapters.
        local go = Trapper:info(T(_("Downloading %1/%2: #%3"), i, #plan, b.number))
        if not go then stopped = true break end
        local ok = api:downloadBook(b.id, dest)
        if ok then ok_count = ok_count + 1 else fail_count = fail_count + 1 end
      end
    end
    Trapper:clear()
    UIManager:show(InfoMessage:new{ text = T(
      _("%1\nDownloaded: %2\nSkipped (exists): %3\nFailed: %4\nFolder: %5"),
      stopped and _("Stopped.") or _("Done"), ok_count, skip_count, fail_count, dest_root) })
  end)
end

return Downloader
