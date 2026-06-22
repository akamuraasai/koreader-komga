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
    close_callback = function() UIManager:close(menu) end,
  }
  return menu
end

-- Run `fetch` inside a Trapper coroutine showing `label`; on success call onOk(res),
-- on failure show a translated error. Centralizes the load+error pattern shared by
-- the series/collections/chapter list screens.
function UiUtil.loadWithTrapper(label, fetch, onOk)
  Trapper:wrap(function()
    Trapper:info(label)
    local res, err = fetch()
    Trapper:clear()
    if not res then
      UIManager:show(InfoMessage:new{ text = T(_("Error: %1"), tostring(err)) })
      return
    end
    onOk(res)
  end)
end

return UiUtil
