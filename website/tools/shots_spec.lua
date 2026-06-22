-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

-- Headless screenshot driver: paints each plugin screen and dumps a PNG.
-- Run: SHOTS_OUT=/abs/dir KOMGA_URL=.. KOMGA_API_KEY=.. ./kodev test front shots
package.path = "plugins/komga.koplugin/?.lua;" .. package.path
require("commonrequire")
require("gettext").changeLang("C")

local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local BB = require("ffi/blitbuffer")
local UiUtil = require("views/ui_util")
local MultiInputDialog = require("ui/widget/multiinputdialog")

require("ui/widget/menu").is_enable_shortcut = false  -- touch-style rows, no Q/W/E hints
MultiInputDialog.onShowKeyboard = function() end

local OUT = os.getenv("SHOTS_OUT")
  or "/Users/jcruz/projects/koreader-komga/website/docs/assets/screenshots"

UiUtil.loadWithTrapper = function(_label, fetch, onOk)  -- fetch synchronously before painting
  local res = fetch()
  if res then onOk(res) end
end

local function reset()
  UIManager._window_stack = {}
  Screen.bb:fill(BB.COLOR_WHITE)
end
local function top() return UIManager._window_stack[#UIManager._window_stack].widget end
local function shoot(name)
  UIManager:_repaint()
  Screen:shot(OUT .. "/" .. name .. ".png")
end

describe("komga screenshots", function()
  local KomgaApi = require("api/komga_api")
  local ChapterPicker = require("views/chapter_picker")
  local api = KomgaApi.new{ base_url = os.getenv("KOMGA_URL"), api_key = os.getenv("KOMGA_API_KEY") }
  local ctx = { download_dir = nil, on_download = function() end }

  local function pickerScreen(title, fetch)
    reset()
    ChapterPicker.show({ title = title, mixed = true, fetch = fetch }, function() end)
  end

  it("captures every screen", function()
    reset()
    require("views/home_browser").show(api, ctx)
    shoot("home")

    pickerScreen("Reading", function() return api:booksInProgress() end)
    shoot("reading")

    reset()
    require("views/series_browser").show(
      { title = "Komga series",
        fetch = function() return api:searchSeriesAll("") end,
        search = function(q) return api:searchSeriesAll(q) end },
      function() end)
    top():onGotoPage(4)
    shoot("series")

    local blame = (api:searchSeriesAll("Blame").items or {})[1]
    reset()
    ChapterPicker.showForSeries(api, { id = blame.id, title = blame.title }, ctx)
    shoot("chapters")

    reset()
    require("views/collections_browser").show(api, ctx)
    shoot("collections")

    reset()
    ChapterPicker.showForSeries(api, { id = blame.id, title = blame.title }, ctx)
    top().onLeftButtonTap()
    shoot("menu")
  end)

  it("captures the settings dialog", function()
    reset()
    require("main").showConfig({ settings = {
      get = function(_self, k)
        if k == "base_url" then return "https://komga.example.com" end
        return "komga_examplekey0000000000"
      end,
    } })
    shoot("settings")
  end)
end)
