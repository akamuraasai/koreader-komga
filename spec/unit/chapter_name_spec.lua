-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local C = require("domain/chapter_name")

describe("ChapterName.forSort", function()
  it("zero-pads integer chapters to 4 digits", function()
    assert.equals("0000.cbz", C.forSort(0))
    assert.equals("0001.cbz", C.forSort(1))
    assert.equals("0016.cbz", C.forSort(16))
    assert.equals("1000.cbz", C.forSort(1000))
  end)
  it("treats integer-valued floats as integers (no trailing .0)", function()
    assert.equals("0016.cbz", C.forSort(16.0))
  end)
  it("keeps the fractional part for decimal chapters", function()
    assert.equals("0005.5.cbz", C.forSort(5.5))
    assert.equals("0016.5.cbz", C.forSort(16.5))
  end)
end)
