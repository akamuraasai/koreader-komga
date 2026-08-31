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
function Settings:naming()
  return {
    template = self:get("filename_template") or "{number}",
    flat = self:get("series_subfolder") == false,
  }
end
local function positiveNumber(v)
  if type(v) == "number" and v > 0 then return v end
end
-- Absent keys mean "use the API defaults" (stall = socketutil's, no total cap).
function Settings:downloadTimeouts()
  return {
    block = positiveNumber(self:get("download_block_timeout")),
    total = positiveNumber(self:get("download_total_timeout")),
  }
end
local function resolveDir(custom)
  return DownloadDir.resolve(
    custom,
    G_reader_settings and G_reader_settings:readSetting("home_dir"),
    require("device").home_dir,
    DataStorage:getFullDataDir())
end
function Settings:downloadDir() return resolveDir(self:get("download_dir")) end
function Settings.defaultDownloadDir(_self) return resolveDir(nil) end

return Settings
