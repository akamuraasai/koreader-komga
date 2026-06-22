-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local UIManager = require("ui/uimanager")
local UiUtil = require("views/ui_util")
local SeriesBrowser = require("views/series_browser")
local CollectionsBrowser = require("views/collections_browser")
local ChapterPicker = require("views/chapter_picker")
local _ = require("gettext")

local HomeBrowser = {}

-- ctx = { download_dir, on_download }
function HomeBrowser.show(api, ctx)
  local menu

  local function openChapters(title, mixed, fetch)
    ChapterPicker.show({
      title = title, mixed = mixed, download_dir = ctx.download_dir, fetch = fetch,
    }, ctx.on_download)
  end

  local function openSeries(title, fetch, search)
    SeriesBrowser.show({ title = title, fetch = fetch, search = search },
      function(series) ChapterPicker.showForSeries(api, series, ctx) end)
  end

  local items = {
    { text = _("Current Reading"), callback = function()
        openChapters(_("Current Reading"), true, function() return api:booksInProgress() end) end },
    { text = _("Deck"), callback = function()
        openChapters(_("Deck"), true, function() return api:onDeck() end) end },
    { text = _("Last Updated"), callback = function()
        openChapters(_("Last Updated"), true, function() return api:booksLatest() end) end },
    { text = _("Last Added Series"), callback = function()
        openSeries(_("Last Added Series"), function() return api:seriesNew() end, nil) end },
    { text = _("Collections"), callback = function()
        CollectionsBrowser.show(api, ctx) end },
    { text = _("All"), callback = function()
        openSeries(_("Komga series"),
          function() return api:searchSeriesAll("") end,
          function(q) return api:searchSeriesAll(q) end) end },
  }

  menu = UiUtil.fullscreenMenu{
    title = _("Komga"),
    item_table = items,
    onMenuSelect = function(_self, item) if item.callback then item.callback() end end,
  }
  UIManager:show(menu)
end

return HomeBrowser
