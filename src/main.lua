-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local NetworkMgr = require("ui/network/manager")
local Settings = require("common/settings")
local _ = require("gettext")

local Komga = WidgetContainer:extend{ name = "komga", is_doc_only = false }

function Komga:init()
  self.settings = Settings.new()
  self.ui.menu:registerToMainMenu(self)
end

function Komga:addToMainMenu(menu_items)
  menu_items.komga = {
    text = _("Komga"),
    sorting_hint = "tools",
    sub_item_table = {
      { text = _("Browse & download"), callback = function() self:onBrowse() end },
      { text = _("Settings"), callback = function() self:showConfig() end },
    },
  }
end

function Komga:showConfig()
  local dialog
  dialog = MultiInputDialog:new{
    title = _("Server"),
    fields = {
      { description = _("URL"), text = self.settings:get("base_url") or "https://" },
      { description = _("API key"), text = self.settings:get("api_key") or "", text_type = "password" },
    },
    buttons = {{
      { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
      { text = _("Save"), callback = function()
          local f = dialog:getFields()
          local KomgaParse = require("api/komga_parse")
          local url = KomgaParse.normalizeBase(f[1] or "")
          local key = (f[2] or ""):gsub("^%s*(.-)%s*$", "%1")
          self.settings:set("base_url", url)
          self.settings:set("api_key", key)
          UIManager:close(dialog)
          UIManager:show(InfoMessage:new{ text = _("Saved") })
        end },
    }},
  }
  UIManager:show(dialog)
  dialog:onShowKeyboard()
end

function Komga:onBrowse()
  if not self.settings:isConfigured() then
    UIManager:show(InfoMessage:new{
      text = _("Set the server URL and API key first."),
      dismiss_callback = function() self:showConfig() end,
    })
    return
  end
  NetworkMgr:runWhenOnline(function() self:openHome() end)
end

function Komga:openHome()
  local KomgaApi = require("api/komga_api")
  local HomeBrowser = require("views/home_browser")
  local api = KomgaApi.new{ base_url = self.settings:get("base_url"), api_key = self.settings:get("api_key") }
  HomeBrowser.show(api, {
    download_dir = self.settings:downloadDir(),
    on_download = function(books, all) self:runDownloads(api, books, all) end,
  })
end

function Komga:runDownloads(api, books, all)
  local Downloader = require("domain/downloader")
  Downloader.run(api, self.settings:downloadDir(), books, all)
end

return Komga
