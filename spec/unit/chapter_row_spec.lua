-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local R = require("views/chapter_row")

local function book(over)
  local b = { seriesTitle = "One Piece", number = "1", completed = false, inProgress = false }
  for k, v in pairs(over or {}) do b[k] = v end
  return b
end

describe("ChapterRow.format", function()
  it("renders an unchecked, unread row", function()
    assert.equals("▢ One Piece #1", R.format(book(), false, false))
  end)
  it("renders a checked row", function()
    assert.equals("✓ One Piece #1", R.format(book(), true, false))
  end)
  it("marks completed chapters with a read glyph", function()
    assert.equals("▢ One Piece #1 ✔", R.format(book{ completed = true }, false, false))
  end)
  it("marks in-progress chapters with an ellipsis", function()
    assert.equals("▢ One Piece #1 …", R.format(book{ inProgress = true }, false, false))
  end)
  it("appends the on-disk marker when downloaded", function()
    assert.equals("▢ One Piece #1 ⤓", R.format(book(), false, true))
    assert.equals("▢ One Piece #1 ✔ ⤓", R.format(book{ completed = true }, false, true))
  end)
  it("falls back to '?' when the series title is missing", function()
    -- build without seriesTitle (a table literal can't carry an explicit nil)
    assert.equals("▢ ? #1",
      R.format({ number = "1", completed = false, inProgress = false }, false, false))
  end)
end)

describe("ChapterRow.base", function()
  it("is the row text without the checkbox", function()
    assert.equals("One Piece #1", R.base(book(), false))
    assert.equals(R.format(book(), false, false), "▢ " .. R.base(book(), false))
  end)
end)

describe("ChapterRow.fromBase", function()
  it("prefixes the checkbox onto a precomputed base", function()
    assert.equals("✓ One Piece #1", R.fromBase(R.base(book(), false), true))
    assert.equals("▢ One Piece #1", R.fromBase(R.base(book(), false), false))
  end)
end)
