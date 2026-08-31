-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local CL = require("views/chapter_list")

local books = {
  { id = "b1", seriesTitle = "One Piece", number = "1", completed = false, inProgress = false },
  { id = "b2", seriesTitle = "One Piece", number = "2", completed = true,  inProgress = false },
}

describe("ChapterList", function()
  it("precomputes one base per book keyed by id", function()
    local bases = CL.precompute(books, { b2 = true })
    assert.equals("One Piece #1", bases.b1)
    assert.equals("One Piece #2 ✔ ⤓", bases.b2)
  end)
  it("builds rows from the base cache, varying only the checkbox", function()
    local bases = CL.precompute(books, {})
    local items = CL.buildItems(books, bases, function(id) return id == "b1" end)
    assert.equals("✓ One Piece #1", items[1].text)
    assert.equals("▢ One Piece #2 ✔", items[2].text)
    assert.equals(books[1], items[1].book)
  end)
  it("emits a single 'No items' placeholder for an empty list", function()
    local items = CL.buildItems({}, {}, function() return false end)
    assert.equals(1, #items)
    assert.equals("No items", items[1].text)
  end)
  it("formats the title with the live count", function()
    assert.equals("One Piece  [3]", CL.title("One Piece", 3))
  end)
end)
