-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local PathUtil = require("common/pathutil")

describe("PathUtil.sanitizeComponent", function()
  it("removes FAT32-illegal characters", function()
    assert.equals("So I'm a Spider, So What", PathUtil.sanitizeComponent("So I'm a Spider, So What?"))
    assert.equals("A B C", PathUtil.sanitizeComponent("A/B:C"))
    assert.equals("x y", PathUtil.sanitizeComponent('x*"<>|y'))
  end)
  it("strips trailing dots and spaces", function()
    assert.equals("name", PathUtil.sanitizeComponent("name... "))
  end)
  it("keeps legal punctuation like apostrophes and dashes", function()
    assert.equals("Don't - Stop", PathUtil.sanitizeComponent("Don't - Stop"))
  end)
  it("never returns empty", function()
    assert.equals("_", PathUtil.sanitizeComponent(""))
    assert.equals("_", PathUtil.sanitizeComponent("///"))
  end)
end)
