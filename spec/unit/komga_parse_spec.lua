-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local P = require("api/komga_parse")

describe("komga_parse URL builders", function()
  it("escapes the search query", function()
    assert.equals(
      "https://k/api/v1/series?search=Battle%20Royale&page=0&size=20&sort=metadata.titleSort,asc",
      P.buildSeriesSearchUrl("https://k", "Battle Royale", 0, 20))
  end)
  it("builds the books url unpaged sorted by numberSort", function()
    assert.equals(
      "https://k/api/v1/series/SID/books?sort=metadata.numberSort,asc&unpaged=true",
      P.buildBooksUrl("https://k", "SID"))
  end)
  it("builds the file url", function()
    assert.equals("https://k/api/v1/books/BID/file", P.buildFileUrl("https://k", "BID"))
  end)
  it("builds the in-progress books url", function()
    assert.equals(
      "https://k/api/v1/books?read_status=IN_PROGRESS&sort=readProgress.readDate,desc&page=0&size=200",
      P.buildBooksInProgressUrl("https://k", 0, 200))
  end)
  it("builds the on-deck url", function()
    assert.equals("https://k/api/v1/books/ondeck?page=0&size=500",
      P.buildOnDeckUrl("https://k", 0, 500))
  end)
  it("builds the latest-books url", function()
    assert.equals("https://k/api/v1/books/latest?page=0&size=200",
      P.buildLatestBooksUrl("https://k", 0, 200))
  end)
  it("builds the new-series url", function()
    assert.equals("https://k/api/v1/series/new?page=0&size=200",
      P.buildNewSeriesUrl("https://k", 0, 200))
  end)
  it("builds the collections url", function()
    assert.equals("https://k/api/v1/collections?page=0&size=500",
      P.buildCollectionsUrl("https://k", 0, 500))
  end)
  it("builds the collection-series url", function()
    assert.equals("https://k/api/v1/collections/C1/series?page=1&size=500",
      P.buildCollectionSeriesUrl("https://k", "C1", 1, 500))
  end)
end)

describe("komga_parse.parseSeriesPage", function()
  it("maps content to items and surfaces totalPages", function()
    local out = P.parseSeriesPage{ totalPages = 1, totalElements = 1, content = {
      { id = "S1", name = "X", metadata = { title = "Battle Royale" }, booksCount = 122, booksUnreadCount = 5 },
    }}
    assert.equals(1, out.totalPages)
    assert.equals("S1", out.items[1].id)
    assert.equals("Battle Royale", out.items[1].title)
    assert.equals(122, out.items[1].booksCount)
    assert.equals(5, out.items[1].unread)
  end)
end)

describe("komga_parse.parseBooksPage", function()
  it("derives completed/inProgress from readProgress", function()
    local out = P.parseBooksPage{ totalElements = 3, content = {
      { id = "b1", metadata = { number = "1", numberSort = 1 }, readProgress = nil },
      { id = "b2", metadata = { number = "2", numberSort = 2 }, readProgress = { completed = true } },
      { id = "b3", metadata = { number = "2.5", numberSort = 2.5 }, readProgress = { completed = false, page = 3 } },
    }}
    assert.is_false(out.items[1].completed)
    assert.is_false(out.items[1].inProgress)
    assert.is_true(out.items[2].completed)
    assert.is_false(out.items[3].completed)
    assert.is_true(out.items[3].inProgress)
    assert.equals(2.5, out.items[3].sort)
  end)

  -- rapidjson decodes JSON null to a non-nil sentinel (userdata), NOT Lua nil.
  -- A thread is a faithful stand-in: non-nil, non-table, and errors if indexed.
  it("treats a non-table readProgress (rapidjson.null) as unread, without indexing it", function()
    local NULL = coroutine.create(function() end)
    local out = P.parseBooksPage{ totalElements = 1, content = {
      { id = "b1", metadata = { number = "1", numberSort = 1 }, readProgress = NULL },
    }}
    assert.is_false(out.items[1].completed)
    assert.is_false(out.items[1].inProgress)
    assert.equals("b1", out.items[1].id)
    assert.equals(1, out.items[1].sort)
  end)

  it("captures seriesTitle for mixed-series lists", function()
    local out = P.parseBooksPage{ totalElements = 1, content = {
      { id = "b1", seriesId = "S9", seriesTitle = "One Piece",
        metadata = { number = "1045", numberSort = 1045 }, readProgress = nil },
    }}
    assert.equals("One Piece", out.items[1].seriesTitle)
  end)

  it("leaves seriesTitle nil when the DTO omits it (the caller fills it)", function()
    local out = P.parseBooksPage{ content = {
      { id = "b1", metadata = { number = "1", numberSort = 1 } },
    }}
    assert.is_nil(out.items[1].seriesTitle)
  end)

  it("treats a non-table metadata (rapidjson.null) as empty without indexing it", function()
    local NULL = coroutine.create(function() end)   -- non-nil, non-table, errors if indexed
    local out = P.parseBooksPage{ content = {
      { id = "b1", metadata = NULL, readProgress = nil },
    }}
    assert.equals("?", out.items[1].number)
    assert.equals(0, out.items[1].sort)
  end)
end)

describe("komga_parse.applySeriesTitle", function()
  it("fills missing series titles with the fallback, preserving present ones", function()
    local out = P.applySeriesTitle({
      { id = "b1", number = "1" },                       -- no seriesTitle
      { id = "b2", number = "2", seriesTitle = "Own" },  -- keeps its own
    }, "Fallback")
    assert.equals("Fallback", out[1].seriesTitle)
    assert.equals("Own", out[2].seriesTitle)
  end)
  it("does not mutate the input books", function()
    local books = { { id = "b1", number = "1" } }
    P.applySeriesTitle(books, "Fallback")
    assert.is_nil(books[1].seriesTitle)
  end)
end)

describe("komga_parse.parseCollectionsPage", function()
  it("maps collections with their series counts", function()
    local out = P.parseCollectionsPage{ totalPages = 1, totalElements = 2, content = {
      { id = "C1", name = "Favorites", seriesIds = { "a", "b", "c" } },
      { id = "C2", name = "To Read", seriesIds = {} },
    }}
    assert.equals(1, out.totalPages)
    assert.equals("C1", out.items[1].id)
    assert.equals("Favorites", out.items[1].name)
    assert.equals(3, out.items[1].seriesCount)
    assert.equals(0, out.items[2].seriesCount)
  end)
  it("tolerates a missing seriesIds array", function()
    local out = P.parseCollectionsPage{ content = { { id = "C3", name = "X" } } }
    assert.equals(0, out.items[1].seriesCount)
  end)
end)

describe("komga_parse.normalizeBase", function()
  it("trims whitespace and trailing slashes", function()
    assert.equals("https://k.example.com", P.normalizeBase("  https://k.example.com/  "))
    assert.equals("https://k.example.com", P.normalizeBase("https://k.example.com///"))
  end)
  it("adds https:// when the scheme is missing", function()
    assert.equals("https://k.example.com", P.normalizeBase("k.example.com"))
  end)
  it("leaves an explicit http scheme intact", function()
    assert.equals("http://192.168.1.5:25600", P.normalizeBase("http://192.168.1.5:25600/"))
  end)
  it("returns empty string unchanged", function()
    assert.equals("", P.normalizeBase(""))
  end)
end)
