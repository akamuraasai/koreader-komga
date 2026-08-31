-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")

-- Stub the runtime modules Settings.new/downloadDir reach for, BEFORE requiring it.
local _saved = {
  ds  = package.loaded["datastorage"],
  ls  = package.loaded["luasettings"],
  dev = package.loaded["device"],
}
package.loaded["datastorage"] = {
  getSettingsDir = function() return "/cfg" end,
  getFullDataDir = function() return "/data" end,
}
local fake_store = { _t = {} }
function fake_store:readSetting(k) return self._t[k] end
function fake_store:saveSetting(k, v) self._t[k] = v end
function fake_store.flush() end
package.loaded["luasettings"] = { open = function() return setmetatable({ _t = {} }, { __index = fake_store }) end }
package.loaded["device"] = { home_dir = "/dev/home" }

local Settings = require("common/settings")

local function with_global_home(home, fn)
  local prev = _G.G_reader_settings
  _G.G_reader_settings = home and { readSetting = function() return home end } or nil
  local ok, err = pcall(fn)
  _G.G_reader_settings = prev
  if not ok then error(err) end
end

describe("Settings:isConfigured", function()
  it("is false until both base_url and api_key are non-empty", function()
    local s = Settings.new()
    assert.is_false(s:isConfigured())
    s:set("base_url", "https://k"); assert.is_false(s:isConfigured())
    s:set("api_key", "KEY");        assert.is_true(s:isConfigured())
  end)
end)

describe("Settings:downloadDir", function()
  it("returns a non-empty custom dir verbatim", function()
    local s = Settings.new(); s:set("download_dir", "/mnt/sd/Manga")
    with_global_home(nil, function() assert.equals("/mnt/sd/Manga", s:downloadDir()) end)
  end)
  it("prefers the file-manager home when no custom dir", function()
    local s = Settings.new()
    with_global_home("/mnt/onboard", function() assert.equals("/mnt/onboard/Komga", s:downloadDir()) end)
  end)
  it("falls back to the device home when no global home", function()
    local s = Settings.new()
    with_global_home(nil, function() assert.equals("/dev/home/Komga", s:downloadDir()) end)
  end)
end)

teardown(function()
  package.loaded["datastorage"]     = _saved.ds
  package.loaded["luasettings"]     = _saved.ls
  package.loaded["device"]          = _saved.dev
  package.loaded["common/settings"] = nil
  package.loaded["common/download_dir"] = nil
end)
