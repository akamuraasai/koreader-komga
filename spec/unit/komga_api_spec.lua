-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local KomgaApi = require("api/komga_api")

local function fake_api()
  local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
  api.calls = {}
  api._getJson = function(self, url)
    self.calls[#self.calls + 1] = url
    if url:find("/series%?") then
      return 200, { totalElements = 1, content = {
        { id = "S1", metadata = { title = "BR" }, booksCount = 2, booksUnreadCount = 2 } } }
    elseif url:find("/books%?") then
      return 200, { totalElements = 1, content = {
        { id = "b1", metadata = { number = "1", numberSort = 1 }, readProgress = nil } } }
    end
    return 404, nil
  end
  return api
end

describe("KomgaApi.listBooks", function()
  it("returns parsed book items", function()
    local api = fake_api()
    local res = assert(api:listBooks("S1"))
    assert.equals("b1", res.items[1].id)
    assert.is_false(res.items[1].completed)
  end)
end)

describe("KomgaApi.downloadBook", function()
  it("reports ok on 200 and failure (with cleanup) otherwise", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._download = function(_, _, _) return 200, {} end
    assert.is_true((api:downloadBook("b1", "/tmp/x.cbz")))
    api._download = function(_, _, _) return 500, nil end
    local ok, err = api:downloadBook("b1", "/tmp/x.cbz")
    assert.is_false(ok)
    assert.truthy(err)
  end)
end)

describe("KomgaApi.downloadBook cleanup", function()
  it("removes the partial file on a non-200 download", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._download = function(_, _, _) return 500, nil end
    local removed
    local real_remove = os.remove
    os.remove = function(p) removed = p; return true end
    local ok = api:downloadBook("b1", "/tmp/x.cbz")
    os.remove = real_remove
    assert.is_false(ok)
    assert.equals("/tmp/x.cbz", removed)
  end)
  it("reports a clear error and does NOT remove when the dest cannot be opened", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._download = function(_, _, _) return -1, nil end
    local removed = false
    local real_remove = os.remove
    os.remove = function() removed = true; return true end
    local ok, err = api:downloadBook("b1", "/tmp/x.cbz")
    os.remove = real_remove
    assert.is_false(ok)
    assert.truthy(err:find("could not open"))
    assert.is_false(removed)
  end)
end)

describe("KomgaApi.listBooks error path", function()
  it("returns nil + err on non-200", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._getJson = function() return 500, nil end
    local res, err = api:listBooks("S1")
    assert.is_nil(res)
    assert.truthy(err)
  end)
end)

describe("KomgaApi.searchSeriesAll pagination", function()
  it("accumulates items across all pages", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._getJson = function(_, url)
      local page = tonumber(url:match("page=(%d+)")) or 0
      if page == 0 then
        return 200, { totalPages = 2, totalElements = 3, content = {
          { id = "S1", metadata = { title = "A" } }, { id = "S2", metadata = { title = "B" } } } }
      end
      return 200, { totalPages = 2, totalElements = 3, content = {
        { id = "S3", metadata = { title = "C" } } } }
    end
    local res = assert(api:searchSeriesAll(""))
    assert.equals(3, #res.items)
    assert.equals("S1", res.items[1].id)
    assert.equals("S3", res.items[3].id)
  end)
  it("returns nil + err if a page request fails", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._getJson = function() return 500, nil end
    local res, err = api:searchSeriesAll("")
    assert.is_nil(res)
    assert.truthy(err)
  end)
end)

describe("KomgaApi flat-list endpoints", function()
  it("booksInProgress pages through all results", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._getJson = function(_, url)
      assert(url:find("read_status=IN_PROGRESS"), "expected the in-progress url")
      local page = tonumber(url:match("page=(%d+)")) or 0
      if page == 0 then
        return 200, { totalPages = 2, content = {
          { id = "b1", seriesId = "S1", seriesTitle = "A", metadata = { number = "1", numberSort = 1 } } } }
      end
      return 200, { totalPages = 2, content = {
        { id = "b2", seriesId = "S2", seriesTitle = "B", metadata = { number = "2", numberSort = 2 } } } }
    end
    local res = assert(api:booksInProgress())
    assert.equals(2, #res.items)
    assert.equals("A", res.items[1].seriesTitle)
  end)

  it("onDeck hits the ondeck endpoint", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    local seen
    api._getJson = function(_, url) seen = url; return 200, { totalPages = 1, content = {} } end
    assert(api:onDeck())
    assert.truthy(seen:find("/books/ondeck"))
  end)

  it("booksLatest requests a single page (does NOT page through)", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    local n = 0
    api._getJson = function(_, url)
      n = n + 1
      assert(url:find("/books/latest"))
      return 200, { totalPages = 5, content = { { id = "b1", metadata = { number = "1", numberSort = 1 } } } }
    end
    local res = assert(api:booksLatest())
    assert.equals(1, n)
    assert.equals(1, #res.items)
  end)

  it("seriesNew hits series/new", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    local seen
    api._getJson = function(_, url) seen = url; return 200, { content = { { id = "S1", metadata = { title = "A" } } } } end
    assert(api:seriesNew())
    assert.truthy(seen:find("/series/new"))
  end)

  it("listCollections parses collections", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._getJson = function() return 200, { totalPages = 1, content = {
      { id = "C1", name = "Fav", seriesIds = { "a", "b" } } } } end
    local res = assert(api:listCollections())
    assert.equals("Fav", res.items[1].name)
    assert.equals(2, res.items[1].seriesCount)
  end)

  it("collectionSeries hits the collection's series", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    local seen
    api._getJson = function(_, url) seen = url; return 200, { totalPages = 1, content = {
      { id = "S1", metadata = { title = "A" } } } } end
    assert(api:collectionSeries("C1"))
    assert.truthy(seen:find("/collections/C1/series"))
  end)

  it("returns nil + err when a flat-list page fails", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    api._getJson = function() return 500, nil end
    local res, err = api:booksInProgress()
    assert.is_nil(res)
    assert.truthy(err)
  end)
end)

describe("KomgaApi.fetchAllPages edge cases", function()
  it("stops at the MAX_PAGES cap even if the server keeps reporting more pages", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    local calls = 0
    api._getJson = function()
      calls = calls + 1
      return 200, { totalPages = 999, content = { { id = "S" .. calls, metadata = { title = "x" } } } }
    end
    local res = assert(api:searchSeriesAll(""))
    assert.equals(50, calls)        -- MAX_PAGES
    assert.equals(50, #res.items)
  end)

  it("breaks early on the first empty page (does not walk all totalPages)", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    local calls = 0
    api._getJson = function()
      calls = calls + 1
      if calls == 1 then
        return 200, { totalPages = 5, content = {
          { id = "S1", metadata = { title = "A" } }, { id = "S2", metadata = { title = "B" } } } }
      end
      return 200, { totalPages = 5, content = {} }  -- empty page 2 -> stop
    end
    local res = assert(api:searchSeriesAll(""))
    assert.equals(2, calls)          -- page 0 + the empty page 1, then break
    assert.equals(2, #res.items)
  end)

  it("fetches a single page when the body omits totalPages (falls back to 1)", function()
    local api = KomgaApi.new{ base_url = "https://k", api_key = "KEY" }
    local calls = 0
    api._getJson = function()
      calls = calls + 1
      return 200, { content = { { id = "S1", metadata = { title = "A" } } } }  -- no totalPages
    end
    local res = assert(api:searchSeriesAll(""))
    assert.equals(1, calls)
    assert.equals(1, #res.items)
  end)
end)
