-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local DR = require("domain/download_result")

describe("DownloadResult", function()
  it("starts at zero, not stopped", function()
    local r = DR.new()
    assert.same({ ok = 0, skip = 0, fail = 0, stopped = false }, r)
  end)
  it("accumulates each outcome", function()
    local r = DR.new()
    DR.ok(r); DR.ok(r); DR.skip(r); DR.fail(r); DR.stop(r)
    assert.equals(2, r.ok); assert.equals(1, r.skip); assert.equals(1, r.fail)
    assert.is_true(r.stopped)
  end)
end)
