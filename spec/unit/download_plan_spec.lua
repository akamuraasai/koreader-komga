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

  it("disambiguates same-sort collisions deterministically (every twin gets its id)", function()
    local plan = Plan.resolve({
      { id = "a", seriesTitle = "X", sort = 0 },
      { id = "b", seriesTitle = "X", sort = 0 },
    }, "/root")
    assert.equals("/root/X/0000_a.cbz", plan[1].dest)
    assert.equals("/root/X/0000_b.cbz", plan[2].dest)
  end)

  it("disambiguates triple+ collisions", function()
    local plan = Plan.resolve({
      { id = "a", seriesTitle = "X", sort = 1 },
      { id = "b", seriesTitle = "X", sort = 1 },
      { id = "c", seriesTitle = "X", sort = 1 },
    }, "/root")
    assert.same({ "/root/X/0001_a.cbz", "/root/X/0001_b.cbz", "/root/X/0001_c.cbz" },
      { plan[1].dest, plan[2].dest, plan[3].dest })
  end)

  it("exposes the series dir for each entry", function()
    local plan = Plan.resolve({ { id = "a", seriesTitle = "X", sort = 1 } }, "/root")
    assert.equals("/root/X", plan[1].dir)
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
