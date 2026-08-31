-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local Trapper = require("ui/trapper")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local DownloadPlan = require("domain/download_plan")
local DownloadResult = require("domain/download_result")
local _ = require("gettext")
local T = require("ffi/util").template

local Downloader = {}

local function ensureDir(path)
  if lfs.attributes(path, "mode") == "directory" then return true end
  util.makePath(path)
  return lfs.attributes(path, "mode") == "directory"
end

-- books: flat list of { id, seriesTitle, number, sort } — the SELECTED subset to download.
-- allBooks: the full visible list used to resolve collision suffixes consistently;
-- defaults to books when omitted (3-arg callers behave identically to before).
-- Each chapter routes to its OWN series folder, so a mixed-series selection
-- (Current Reading / Deck / Last Updated) downloads correctly.
function Downloader.run(api, dest_root, books, allBooks)
  Trapper:wrap(function()
    local r = DownloadResult.new()
    local ensured = {}
    -- Resolve destinations over the FULL visible set so collision suffixes are stable
    -- regardless of how many twins are selected in a single action.
    local plan = DownloadPlan.resolve(allBooks or books, dest_root)
    -- Filter to only the entries the caller actually selected.
    local wanted = {}
    for _, b in ipairs(books) do wanted[b.id] = true end
    local todo = {}
    for _, item in ipairs(plan) do
      if wanted[item.book.id] then todo[#todo + 1] = item end
    end
    for i, item in ipairs(todo) do
      local b, dest, dir = item.book, item.dest, item.dir
      local go = Trapper:info(T(_("Downloading %1/%2: #%3"), i, #todo, b.number))
      if not go then DownloadResult.stop(r) break end
      if not ensured[dir] then
        if ensureDir(dir) then ensured[dir] = true end
      end
      if not ensured[dir] then
        DownloadResult.fail(r)
      elseif lfs.attributes(dest, "mode") == "file" then
        DownloadResult.skip(r)
      else
        if api:downloadBook(b.id, dest) then DownloadResult.ok(r) else DownloadResult.fail(r) end
      end
    end

    Trapper:clear()
    UIManager:show(InfoMessage:new{ text = T(
      _("%1\nDownloaded: %2\nSkipped (exists): %3\nFailed: %4\nFolder: %5"),
      r.stopped and _("Stopped.") or _("Done"), r.ok, r.skip, r.fail, dest_root) })
  end)
end

return Downloader
