-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local Paging = require("domain/paging")

describe("Paging.firstVisibleIndex", function()
  it("returns the 1-based index of the first item on a page", function()
    assert.equals(1, Paging.firstVisibleIndex(1, 10))
    assert.equals(11, Paging.firstVisibleIndex(2, 10))
    assert.equals(21, Paging.firstVisibleIndex(3, 10))
  end)
  it("returns nil when page or perpage is unknown", function()
    assert.is_nil(Paging.firstVisibleIndex(nil, 10))
    assert.is_nil(Paging.firstVisibleIndex(1, nil))
    assert.is_nil(Paging.firstVisibleIndex(nil, nil))
  end)
end)

describe("Paging.hasMore", function()
  it("is true while the next page index is below totalPages", function()
    assert.is_true(Paging.hasMore(1, 3))
    assert.is_false(Paging.hasMore(3, 3))
  end)
  it("treats a missing totalPages as a single page", function()
    assert.is_false(Paging.hasMore(1, nil))
  end)
end)
