-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local UIManager = require("ui/uimanager")
local UiUtil = require("views/ui_util")
local SeriesBrowser = require("views/series_browser")
local ChapterPicker = require("views/chapter_picker")
local _ = require("gettext")

local CollectionsBrowser = {}

-- ctx = { download_dir, on_download }
function CollectionsBrowser.show(api, ctx)
  local menu

  local function openCollection(collection)
    SeriesBrowser.show({
      title = collection.name,
      fetch = function() return api:collectionSeries(collection.id) end,
    }, function(series) ChapterPicker.showForSeries(api, series, ctx) end)
  end

  local function fillItems(res)
    local rows = {}
    for _, c in ipairs(res.items or {}) do
      rows[#rows + 1] = { text = string.format("%s  (%d)", c.name, c.seriesCount), collection = c }
    end
    UiUtil.listMenu(menu, _("Collections"), rows, {})
  end

  local function load()
    UiUtil.loadWithTrapper(_("Loading…"), function() return api:listCollections() end,
      fillItems, function() fillItems({ items = {} }) end)
  end

  menu = UiUtil.fullscreenMenu{
    title = _("Collections"),
    onMenuSelect = function(_self, item)
      if item.is_refresh then load()
      elseif item.collection then openCollection(item.collection) end
    end,
  }
  UIManager:show(menu)
  load()
end

return CollectionsBrowser
