-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local ChapterRow = {}

-- Literal UTF-8 glyphs (LuaJIT has no \u{} escapes). These render in KOReader's font.
local CHECK = "✓ "    -- U+2713
local UNCHECK = "▢ "  -- U+25A2
local READ = "✔"      -- U+2714
local ONDISK = "⤓"    -- U+2913  already downloaded

-- Status suffix for a book: read / in-progress, plus an on-disk marker.
function ChapterRow.status(book, isDownloaded)
  local s = book.completed and (" " .. READ) or (book.inProgress and " …" or "")
  if isDownloaded then s = s .. " " .. ONDISK end
  return s
end

-- The immutable part of a row (everything except the checkbox), so callers can cache
-- it once per load and only vary the checkbox per tap (see chapter_picker rebuild).
function ChapterRow.base(book, isDownloaded)
  return (book.seriesTitle or "?") .. " #" .. tostring(book.number) .. ChapterRow.status(book, isDownloaded)
end

-- Compose the full row from a precomputed base, varying only the checkbox (O(1) per tap).
function ChapterRow.fromBase(base, isSelected)
  return (isSelected and CHECK or UNCHECK) .. base
end

-- Full row text: "<checkbox><seriesTitle> #<number><status>".
function ChapterRow.format(book, isSelected, isDownloaded)
  return ChapterRow.fromBase(ChapterRow.base(book, isDownloaded), isSelected)
end

return ChapterRow
