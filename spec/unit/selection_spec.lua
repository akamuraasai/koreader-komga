-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local S = require("domain/selection")

local books = {
  { id = "1",   sort = 1,    completed = true },
  { id = "2",   sort = 2,    completed = true },
  { id = "2.5", sort = 2.5,  completed = false },
  { id = "3",   sort = 3,    completed = false },
  { id = "4",   sort = 4,    completed = false },
}

describe("Selection.unreadIds", function()
  it("returns all not-completed ids", function()
    assert.same({ "2.5", "3", "4" }, S.unreadIds(books))
  end)
end)

describe("Selection.nextNUnread", function()
  it("returns next n unread after the highest completed sort", function()
    assert.same({ "2.5", "3" }, S.nextNUnread(books, 2))
  end)
  it("caps at what is available", function()
    assert.same({ "2.5", "3", "4" }, S.nextNUnread(books, 10))
  end)
  it("starts at the beginning when nothing is completed", function()
    local none = {
      { id = "a", sort = 5, completed = false },
      { id = "b", sort = 1, completed = false },
    }
    assert.same({ "b", "a" }, S.nextNUnread(none, 5))
  end)
  it("returns empty for n = 0", function()
    assert.same({}, S.nextNUnread(books, 0))
  end)
end)
