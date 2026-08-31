-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local DownloadDir = require("common/download_dir")

local Settings = {}
Settings.__index = Settings

function Settings.new()
  local path = DataStorage:getSettingsDir() .. "/komga_settings.lua"
  return setmetatable({ store = LuaSettings:open(path) }, Settings)
end

function Settings:get(key) return self.store:readSetting(key) end
function Settings:set(key, value)
  self.store:saveSetting(key, value)
  self.store:flush()
end
function Settings:isConfigured()
  return (self:get("base_url") or "") ~= "" and (self:get("api_key") or "") ~= ""
end
function Settings:downloadDir()
  return DownloadDir.resolve(
    self:get("download_dir"),
    G_reader_settings and G_reader_settings:readSetting("home_dir"),
    require("device").home_dir,
    DataStorage:getFullDataDir())
end

return Settings
