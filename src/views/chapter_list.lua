-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local ChapterRow = require("views/chapter_row")
local _ = require("gettext")

local ChapterList = {}

-- Cache the immutable part of each row ONCE per (re)load; per tap only the checkbox varies.
function ChapterList.precompute(books, downloaded)
  local bases = {}
  for _, b in ipairs(books) do bases[b.id] = ChapterRow.base(b, downloaded[b.id]) end
  return bases
end

function ChapterList.buildItems(books, bases, has)
  local items = {}
  if #books == 0 then items[1] = { text = _("No items") }; return items end
  for _, b in ipairs(books) do
    items[#items + 1] = { text = ChapterRow.fromBase(bases[b.id], has(b.id)), book = b }
  end
  return items
end

function ChapterList.title(baseTitle, count)
  return baseTitle .. "  [" .. count .. "]"
end

return ChapterList
