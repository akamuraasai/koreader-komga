-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local DownloadDir = require("common/download_dir")

describe("DownloadDir.resolve", function()
  it("prefers the file-manager home setting", function()
    assert.equals("/mnt/onboard/Komga",
      DownloadDir.resolve("/mnt/onboard", "/dev/home", "/data"))
  end)
  it("falls back to the device home when no setting", function()
    assert.equals("/dev/home/Komga", DownloadDir.resolve(nil, "/dev/home", "/data"))
  end)
  it("falls back to the data dir as a last resort", function()
    assert.equals("/data/Komga", DownloadDir.resolve(nil, nil, "/data"))
  end)
end)
