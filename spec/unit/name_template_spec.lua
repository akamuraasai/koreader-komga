-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local NameTemplate = require("domain/name_template")

describe("NameTemplate.render", function()
  it("substitutes placeholders with context values", function()
    assert.equals("One Piece_0001",
      NameTemplate.render("{series}_{number}", { series = "One Piece", number = "0001" }))
    assert.equals("One Piece-Romance Dawn-0001",
      NameTemplate.render("{series}-{title}-{number}",
        { series = "One Piece", title = "Romance Dawn", number = "0001" }))
  end)

  it("sanitizes FAT-illegal characters from values and template literals", function()
    assert.equals("Re Zero_0001",
      NameTemplate.render("{series}_{number}", { series = "Re:Zero", number = "0001" }))
    assert.equals("A B_0001",
      NameTemplate.render("A/B_{number}", { number = "0001" }))
  end)

  it("drops one adjacent separator for an empty or missing value", function()
    assert.equals("One Piece-0001",
      NameTemplate.render("{series}-{title}-{number}",
        { series = "One Piece", title = "", number = "0001" }))
    assert.equals("One Piece-0001",
      NameTemplate.render("{series}-{title}-{number}",
        { series = "One Piece", number = "0001" }))
    assert.equals("0001",
      NameTemplate.render("{title}-{number}", { number = "0001" }))
  end)

  it("keeps a negative number's sign next to a separator", function()
    assert.equals("A--0002",
      NameTemplate.render("{series}-{number}", { series = "A", number = "-0002" }))
  end)

  it("falls back to the number when the template renders empty", function()
    assert.equals("0001", NameTemplate.render("{title}", { number = "0001" }))
  end)
end)

describe("NameTemplate.validate", function()
  it("accepts the known placeholders", function()
    assert.is_true((NameTemplate.validate("{series}-{title}-{number}")))
    assert.is_true((NameTemplate.validate("{number}")))
  end)

  it("rejects an unknown placeholder, naming it", function()
    local ok, kind, detail = NameTemplate.validate("{serie}_{number}")
    assert.is_false(ok)
    assert.equals("unknown", kind)
    assert.equals("serie", detail)
  end)

  it("requires {number} so distinct chapters get distinct names", function()
    local ok, kind = NameTemplate.validate("{series}-{title}")
    assert.is_false(ok)
    assert.equals("missing_number", kind)
  end)

  it("requires {series} when downloads are flat (no per-series folder)", function()
    local ok, kind = NameTemplate.validate("{number}", { flat = true })
    assert.is_false(ok)
    assert.equals("missing_series", kind)
    assert.is_true((NameTemplate.validate("{series}_{number}", { flat = true })))
  end)
end)
