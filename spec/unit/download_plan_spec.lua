-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local Plan = require("domain/download_plan")

describe("DownloadPlan.resolve", function()
  it("maps distinct books to distinct paths without suffixes", function()
    local plan = Plan.resolve({
      { id = "a", seriesTitle = "X", sort = 1 },
      { id = "b", seriesTitle = "X", sort = 2 },
    }, "/root")
    assert.equals("/root/X/0001.cbz", plan[1].dest)
    assert.equals("/root/X/0002.cbz", plan[2].dest)
    assert.equals("a", plan[1].book.id)
  end)

  it("disambiguates same-sort collisions with the book id (no silent skip)", function()
    local plan = Plan.resolve({
      { id = "a", seriesTitle = "X", sort = 0 },
      { id = "b", seriesTitle = "X", sort = 0 },
    }, "/root")
    assert.equals("/root/X/0000.cbz", plan[1].dest)
    assert.equals("/root/X/0000_b.cbz", plan[2].dest)
  end)

  it("does not collide across different series (separate folders)", function()
    local plan = Plan.resolve({
      { id = "a", seriesTitle = "X", sort = 0 },
      { id = "b", seriesTitle = "Y", sort = 0 },
    }, "/root")
    assert.equals("/root/X/0000.cbz", plan[1].dest)
    assert.equals("/root/Y/0000.cbz", plan[2].dest)
  end)
end)
