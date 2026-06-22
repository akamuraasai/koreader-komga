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
