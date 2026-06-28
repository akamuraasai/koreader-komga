-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local KomgaParse = {}

local function urlencode(s)
  return (tostring(s):gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

function KomgaParse.normalizeBase(url)
  local s = (url or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then return "" end
  if not s:find("^%w[%w+.-]*://") then s = "https://" .. s end
  return (s:gsub("/+$", ""))
end

function KomgaParse.buildSeriesSearchUrl(base, query, page, size)
  return string.format(
    "%s/api/v1/series?search=%s&page=%d&size=%d&sort=metadata.titleSort,asc",
    base, urlencode(query or ""), page, size)
end

function KomgaParse.buildBooksUrl(base, seriesId)
  return string.format(
    "%s/api/v1/series/%s/books?sort=metadata.numberSort,asc&unpaged=true", base, seriesId)
end

function KomgaParse.buildFileUrl(base, bookId)
  return string.format("%s/api/v1/books/%s/file", base, bookId)
end

function KomgaParse.buildBooksInProgressUrl(base, page, size)
  return string.format(
    "%s/api/v1/books?read_status=IN_PROGRESS&sort=readProgress.readDate,desc&page=%d&size=%d",
    base, page, size)
end

function KomgaParse.buildOnDeckUrl(base, page, size)
  return string.format("%s/api/v1/books/ondeck?page=%d&size=%d", base, page, size)
end

function KomgaParse.buildLatestBooksUrl(base, page, size)
  return string.format("%s/api/v1/books/latest?page=%d&size=%d", base, page, size)
end

function KomgaParse.buildNewSeriesUrl(base, page, size)
  return string.format("%s/api/v1/series/new?page=%d&size=%d", base, page, size)
end

function KomgaParse.buildCollectionsUrl(base, page, size)
  return string.format("%s/api/v1/collections?page=%d&size=%d", base, page, size)
end

function KomgaParse.buildCollectionSeriesUrl(base, collectionId, page, size)
  return string.format("%s/api/v1/collections/%s/series?page=%d&size=%d",
    base, collectionId, page, size)
end

function KomgaParse.parseSeriesPage(t)
  local out = { totalPages = t.totalPages or 1, items = {} }
  for _, s in ipairs(t.content or {}) do
    out.items[#out.items + 1] = {
      id = s.id,
      title = (s.metadata and s.metadata.title) or s.name,
      booksCount = s.booksCount or 0,
      unread = s.booksUnreadCount or 0,
    }
  end
  return out
end

function KomgaParse.parseBooksPage(t)
  local out = { totalPages = t.totalPages or 1, items = {} }
  for _, b in ipairs(t.content or {}) do
    -- rapidjson decodes JSON null to a userdata sentinel, NOT nil -- so an unread
    -- book's readProgress (null) must be type-checked as a table, not `~= nil`.
    local rp = b.readProgress
    local hasProgress = type(rp) == "table"
    local completed = hasProgress and rp.completed == true
    local md = type(b.metadata) == "table" and b.metadata or {}
    out.items[#out.items + 1] = {
      id = b.id,
      -- Mixed-series views (Reading/Deck/Latest) keep the DTO's own seriesTitle; Komga
      -- always sets it. If ever absent, the row shows "?" and downloads group under "_/"
      -- (graceful, never a crash) -- single-series leaves backfill via applySeriesTitle.
      seriesTitle = b.seriesTitle,
      number = md.number or "?",
      sort = md.numberSort or 0,
      completed = completed,
      inProgress = hasProgress and not completed,
    }
  end
  return out
end

function KomgaParse.parseCollectionsPage(t)
  local out = { totalPages = t.totalPages or 1, items = {} }
  for _, c in ipairs(t.content or {}) do
    local seriesIds = type(c.seriesIds) == "table" and c.seriesIds or {}
    out.items[#out.items + 1] = {
      id = c.id,
      name = c.name or "?",
      seriesCount = #seriesIds,
    }
  end
  return out
end

-- Single-series leaf views know the series title but the book DTOs may omit it.
-- Return a NEW list of books with each missing seriesTitle filled from `title`
-- (books that already carry their own title keep it). Pure: does not mutate input.
function KomgaParse.applySeriesTitle(books, title)
  local out = {}
  for i, b in ipairs(books) do
    local copy = {}
    for k, v in pairs(b) do copy[k] = v end
    copy.seriesTitle = b.seriesTitle or title
    out[i] = copy
  end
  return out
end

return KomgaParse
