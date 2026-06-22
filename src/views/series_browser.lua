-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local UiUtil = require("views/ui_util")
local _ = require("gettext")

local SeriesBrowser = {}

-- opts = {
--   title  = string,
--   fetch  = function() return { items = {series...} } | nil, err end,
--   search = function(query) return { items = {...} } end | nil,  -- adds a search row
-- }
function SeriesBrowser.show(opts, on_pick)
  local menu

  local function fillItems(res)
    local items = {}
    if opts.search then items[#items + 1] = { text = _("Search"), is_search = true } end
    items[#items + 1] = { text = "↻ " .. _("Refresh"), is_refresh = true }
    for _, s in ipairs(res.items or {}) do
      items[#items + 1] = {
        text = string.format("%s  (%d/%d)", s.title, s.unread, s.booksCount),
        series = s,
      }
    end
    if #(res.items or {}) == 0 then items[#items + 1] = { text = _("No items") } end
    menu:switchItemTable(opts.title, items)
  end

  local function load(fetch)
    UiUtil.loadWithTrapper(_("Searching…"), fetch, fillItems)
  end

  local function openSearch()
    local dlg
    dlg = InputDialog:new{
      title = _("Search"),
      input = "",
      buttons = {{
        { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
        { text = _("Search"), is_enter_default = true, callback = function()
            local q = dlg:getInputText()
            UIManager:close(dlg)
            load(function() return opts.search(q) end)
          end },
      }},
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
  end

  menu = UiUtil.fullscreenMenu{
    title = opts.title,
    onMenuSelect = function(_self, item)
      if item.is_search then
        openSearch()
      elseif item.is_refresh then
        load(opts.fetch)
      elseif item.series then
        on_pick(item.series)
      end
    end,
  }
  UIManager:show(menu)
  load(opts.fetch)
end

return SeriesBrowser
