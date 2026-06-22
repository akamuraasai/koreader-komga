-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local KomgaParse = require("api/komga_parse")

local KomgaApi = {}
KomgaApi.__index = KomgaApi

local MAX_PAGES = 50
local PAGE_SIZE = 500
local RECENCY_SIZE = 200  -- single-page size for the "latest"/"new" recency views

function KomgaApi.new(opts)
  return setmetatable({
    base_url = (opts.base_url or ""):gsub("/+$", ""),
    api_key = opts.api_key,
  }, KomgaApi)
end

-- Real transport (overridden in tests). Requires KOReader/luasocket at runtime.
function KomgaApi:_getJson(url)
  local http = require("socket.http")
  local socket = require("socket")
  local ltn12 = require("ltn12")
  local socketutil = require("socketutil")
  local rapidjson = require("rapidjson")
  local chunks = {}
  socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
  local code = socket.skip(1, http.request{
    url = url,
    headers = { ["X-API-Key"] = self.api_key, ["Accept"] = "application/json" },
    sink = ltn12.sink.table(chunks),
  })
  socketutil:reset_timeout()
  if code ~= 200 then return code, nil end
  local ok, decoded = pcall(rapidjson.decode, table.concat(chunks))
  if not ok then return code, nil end
  return code, decoded
end

function KomgaApi:_download(url, dest_path)
  local http = require("socket.http")
  local socket = require("socket")
  local socketutil = require("socketutil")
  local fh = io.open(dest_path, "wb")
  if not fh then return -1 end
  socketutil:set_timeout(socketutil.FILE_BLOCK_TIMEOUT, socketutil.FILE_TOTAL_TIMEOUT)
  local code = socket.skip(1, http.request{
    url = url,
    headers = { ["X-API-Key"] = self.api_key },
    sink = socketutil.file_sink(fh),
  })
  socketutil:reset_timeout()
  return code
end

-- Page through any list endpoint until exhausted (or MAX_PAGES). buildUrl(page, size)
-- returns the URL for a page; parse(body) returns { items = {...} }.
local function fetchAllPages(self, buildUrl, parse)
  local items, page = {}, 0
  while page < MAX_PAGES do
    local code, body = self:_getJson(buildUrl(page, PAGE_SIZE))
    if code ~= 200 or not body then return nil, "request failed (" .. tostring(code) .. ")" end
    local parsed = parse(body)
    for _, it in ipairs(parsed.items) do items[#items + 1] = it end
    page = page + 1
    if page >= (body.totalPages or 1) or #parsed.items == 0 then break end
  end
  return { total = #items, items = items }
end

-- Fetch a single endpoint and parse it. `label` ("books"/"series") tags the error.
local function fetchOne(self, url, parse, label)
  local code, body = self:_getJson(url)
  if code ~= 200 or not body then return nil, label .. " request failed (" .. tostring(code) .. ")" end
  return parse(body)
end

function KomgaApi:searchSeriesAll(query)
  return fetchAllPages(self, function(page, size)
    return KomgaParse.buildSeriesSearchUrl(self.base_url, query, page, size)
  end, KomgaParse.parseSeriesPage)
end

function KomgaApi:listBooks(seriesId)
  return fetchOne(self, KomgaParse.buildBooksUrl(self.base_url, seriesId), KomgaParse.parseBooksPage, "books")
end

-- "Current Reading": chapters you've partially read, across all series (fetch all).
function KomgaApi:booksInProgress()
  return fetchAllPages(self, function(page, size)
    return KomgaParse.buildBooksInProgressUrl(self.base_url, page, size)
  end, KomgaParse.parseBooksPage)
end

-- "Deck": the next-to-read chapter of each started series (fetch all; small).
function KomgaApi:onDeck()
  return fetchAllPages(self, function(page, size)
    return KomgaParse.buildOnDeckUrl(self.base_url, page, size)
  end, KomgaParse.parseBooksPage)
end

-- "Collections" and a collection's series (fetch all; usually few).
function KomgaApi:listCollections()
  return fetchAllPages(self, function(page, size)
    return KomgaParse.buildCollectionsUrl(self.base_url, page, size)
  end, KomgaParse.parseCollectionsPage)
end

function KomgaApi:collectionSeries(collectionId)
  return fetchAllPages(self, function(page, size)
    return KomgaParse.buildCollectionSeriesUrl(self.base_url, collectionId, page, size)
  end, KomgaParse.parseSeriesPage)
end

-- "Last Updated": most recently added chapters. Intentionally ONE page (RECENCY_SIZE),
-- this is a recency view, not an exhaustive list. (Documented cap, see README.)
function KomgaApi:booksLatest()
  return fetchOne(self, KomgaParse.buildLatestBooksUrl(self.base_url, 0, RECENCY_SIZE),
    KomgaParse.parseBooksPage, "books")
end

-- "Last Added Series": most recently added series. Intentionally ONE page (RECENCY_SIZE).
function KomgaApi:seriesNew()
  return fetchOne(self, KomgaParse.buildNewSeriesUrl(self.base_url, 0, RECENCY_SIZE),
    KomgaParse.parseSeriesPage, "series")
end

function KomgaApi:downloadBook(bookId, dest_path)
  local code = self:_download(KomgaParse.buildFileUrl(self.base_url, bookId), dest_path)
  if code == -1 then
    return false, "could not open destination file: " .. dest_path
  end
  if code ~= 200 then
    os.remove(dest_path) -- no resume: drop partials
    return false, "download failed (" .. tostring(code) .. ")"
  end
  return true
end

return KomgaApi
