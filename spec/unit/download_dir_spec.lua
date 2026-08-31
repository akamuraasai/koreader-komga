-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local DownloadDir = require("common/download_dir")

describe("DownloadDir.resolve", function()
  it("returns a non-empty custom dir verbatim (no /Komga suffix)", function()
    assert.equals("/mnt/sd/Manga", DownloadDir.resolve("/mnt/sd/Manga", "/dev/home", "/data"))
  end)
  it("ignores an empty custom dir", function()
    assert.equals("/dev/home/Komga", DownloadDir.resolve("", "/dev/home", "/data"))
  end)
  it("prefers the file-manager home setting", function()
    assert.equals("/mnt/onboard/Komga", DownloadDir.resolve(nil, "/mnt/onboard", "/dev/home", "/data"))
  end)
  it("falls back to the device home when no setting", function()
    assert.equals("/dev/home/Komga", DownloadDir.resolve(nil, nil, "/dev/home", "/data"))
  end)
  it("falls back to the data dir as a last resort", function()
    assert.equals("/data/Komga", DownloadDir.resolve(nil, nil, nil, "/data"))
  end)
end)
