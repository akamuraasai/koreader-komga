-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local InputDialog = require("ui/widget/inputdialog")
local NetworkMgr = require("ui/network/manager")
local Settings = require("common/settings")
local _ = require("gettext")
local T = require("ffi/util").template

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
      { text = _("Settings"), sub_item_table = {
        { text = _("Server"), keep_menu_open = true, callback = function() self:showConfig() end },
        { text = _("Download folder"), keep_menu_open = true, callback = function() self:chooseDownloadDir() end },
        { text = _("Filename template"), keep_menu_open = true, callback = function() self:editFilenameTemplate() end },
        { text = _("Per-series subfolder"),
          checked_func = function() return self.settings:get("series_subfolder") ~= false end,
          callback = function() self:toggleSeriesSubfolder() end },
      } },
    },
  }
end

function Komga:chooseDownloadDir()
  local PathChooser = require("ui/widget/pathchooser")
  UIManager:show(PathChooser:new{
    select_directory = true,
    select_file = false,
    path = self.settings:downloadDir(),
    onConfirm = function(path)
      self.settings:set("download_dir", path)
      UIManager:show(InfoMessage:new{ text = T(_("Downloads will be saved to:\n%1"), path) })
    end,
  })
end

local function namingError(kind, detail)
  if kind == "unknown" then
    return T(_("Unknown placeholder: {%1}. Valid: {series}, {title}, {number}"), detail)
  elseif kind == "missing_number" then
    return _("The template must contain {number}.")
  end
  return _("Without per-series subfolders the template must contain {series}.")
end

function Komga:editFilenameTemplate()
  local NameTemplate = require("domain/name_template")
  local dialog
  dialog = InputDialog:new{
    title = _("Filename template"),
    input = self.settings:naming().template,
    description = _("Placeholders: {series}, {title}, {number}.\nExample: {series}-{title}-{number}\nAlready-downloaded chapters keep their old names and will download again under a new template."),
    buttons = {{
      { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
      { text = _("Save"), callback = function()
          local template = dialog:getInputText():gsub("^%s*(.-)%s*$", "%1")
          local ok, kind, detail = NameTemplate.validate(template, { flat = self.settings:naming().flat })
          if not ok then
            UIManager:show(InfoMessage:new{ text = namingError(kind, detail) })
            return
          end
          self.settings:set("filename_template", template)
          UIManager:close(dialog)
          UIManager:show(InfoMessage:new{ text = _("Saved") })
        end },
    }},
  }
  UIManager:show(dialog)
  dialog:onShowKeyboard()
end

function Komga:toggleSeriesSubfolder()
  local NameTemplate = require("domain/name_template")
  local flat = self.settings:get("series_subfolder") ~= false  -- toggling OFF means flat
  if flat then
    local ok, kind, detail = NameTemplate.validate(self.settings:naming().template, { flat = true })
    if not ok then
      UIManager:show(InfoMessage:new{ text = namingError(kind, detail) })
      return
    end
  end
  self.settings:set("series_subfolder", not flat)
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
    naming = self.settings:naming(),
    on_download = function(books, all) self:runDownloads(api, books, all) end,
  })
end

function Komga:runDownloads(api, books, all)
  local Downloader = require("domain/downloader")
  Downloader.run(api, self.settings:downloadDir(), books, all, self.settings:naming())
end

return Komga
