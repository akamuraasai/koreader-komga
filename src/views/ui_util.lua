-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Trapper = require("ui/trapper")
local Screen = require("device").screen
local _ = require("gettext")
local T = require("ffi/util").template

local UiUtil = {}

-- Build a borderless full-screen Menu with this plugin's common chrome. `cfg` carries
-- the per-screen bits: title, item_table, onMenuSelect, and optionally
-- title_bar_left_icon + onLeftButtonTap. Returns the Menu instance.
function UiUtil.fullscreenMenu(cfg)
  local menu
  menu = Menu:new{
    title = cfg.title,
    item_table = cfg.item_table or {},
    is_borderless = true,
    is_popout = false,
    width = Screen:getWidth(),
    height = Screen:getHeight(),
    title_bar_left_icon = cfg.title_bar_left_icon,
    onLeftButtonTap = cfg.onLeftButtonTap,
    onMenuSelect = cfg.onMenuSelect,
  }
  return menu
end

-- Run `fetch` inside a Trapper coroutine showing `label`; on success call onOk(res),
-- on failure show a translated error and call the optional onErr(err). Centralizes
-- the load+error pattern shared by the series/collections/chapter list screens.
function UiUtil.loadWithTrapper(label, fetch, onOk, onErr)
  Trapper:wrap(function()
    Trapper:info(label)
    local res, err = fetch()
    Trapper:clear()
    if not res then
      UIManager:show(InfoMessage:new{ text = T(_("Error: %1"), tostring(err)) })
      if onErr then onErr(err) end
      return
    end
    onOk(res)
  end)
end

-- Prepend optional Search row, a Refresh row, the data rows, and a "No items"
-- fallback when rows is empty, then switch the menu's item table.
function UiUtil.listMenu(menu, title, rows, opts)
  opts = opts or {}
  local items = {}
  if opts.search then items[#items + 1] = { text = _("Search"), is_search = true } end
  items[#items + 1] = { text = "↻ " .. _("Refresh"), is_refresh = true }
  for _, r in ipairs(rows) do items[#items + 1] = r end
  if #rows == 0 then items[#items + 1] = { text = _("No items") } end
  menu:switchItemTable(title, items)
end

return UiUtil
