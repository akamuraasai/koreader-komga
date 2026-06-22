-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

-- UI integration tests: drive the plugin's modules in the real KOReader frontend,
-- headless. Run: make test-integration  (cd <koreader> && ./kodev test front komga)

package.path = "plugins/komga.koplugin/?.lua;" .. package.path
require("commonrequire")
require("gettext").changeLang("C")  -- English labels regardless of host locale

local UIManager = require("ui/uimanager")
local Trapper = require("ui/trapper")
local UiUtil = require("views/ui_util")
local InputDialog = require("ui/widget/inputdialog")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local util = require("util")

-- This KOReader build has no util.tmpdir; make a fresh dir from a unique temp name.
local function tmpdir()
  local p = os.tmpname()
  os.remove(p)
  util.makePath(p)
  return p
end

local function sample_books()
  return {
    { id = "b1", seriesTitle = "One Piece", number = "1", sort = 1, completed = false, inProgress = false },
    { id = "b2", seriesTitle = "One Piece", number = "2", sort = 2, completed = true,  inProgress = false },
    { id = "b3", seriesTitle = "One Piece", number = "3", sort = 3, completed = false, inProgress = true },
  }
end

local function sample_series()
  return {
    { id = "s1", title = "One Piece", unread = 3, booksCount = 10 },
    { id = "s2", title = "Naruto",    unread = 0, booksCount = 72 },
  }
end

local function sample_collections()
  return { { id = "c1", name = "Shonen", seriesCount = 5 } }
end

-- Stubbed api; methods are colon-callable (first arg is self). Override per test.
local function fake_api(overrides)
  local api = {
    booksInProgress  = function() return { items = sample_books() } end,
    onDeck           = function() return { items = sample_books() } end,
    booksLatest      = function() return { items = sample_books() } end,
    seriesNew        = function() return { items = sample_series() } end,
    searchSeriesAll  = function(_self, _q) return { items = sample_series() } end,
    listCollections  = function() return { items = sample_collections() } end,
    collectionSeries = function(_self, _id) return { items = sample_series() } end,
    listBooks        = function(_self, _id) return { items = sample_books() } end,
    downloadBook     = function(_self, _id, _dest) return true end,
  }
  for k, v in pairs(overrides or {}) do api[k] = v end
  return api
end

local function fake_settings(dir)
  local store = {}
  return {
    _store = store,
    get = function(_self, k) return store[k] end,
    set = function(_self, k, v) store[k] = v end,
    isConfigured = function(_self)
      return (store.base_url or "") ~= "" and (store.api_key or "") ~= ""
    end,
    downloadDir = function() return dir end,
  }
end

local shown, closed
local function last_match(list, pred)
  for i = #list, 1, -1 do if pred(list[i]) then return list[i] end end
end
local function last_menu()
  return last_match(shown, function(w) return type(w) == "table" and w.item_table and w.onMenuSelect end)
end
local function last_dialog()
  return last_match(shown, function(w) return type(w) == "table" and w.buttons and not w.item_table end)
end
local function last_info()
  return last_match(shown, function(w)
    return type(w) == "table" and w.text ~= nil and not w.item_table and not w.buttons and not w.fields
  end)
end
local function tap_button(widget, label)
  if not (widget and widget.buttons) then return false end
  for _, row in ipairs(widget.buttons) do
    for _, btn in ipairs(row) do
      if btn.text and btn.text:find(label, 1, true) then btn.callback(); return true end
    end
  end
  return false
end

-- The browsers fetch via UiUtil.loadWithTrapper, the downloader drives a Trapper
-- coroutine, and dialogs pop a virtual keyboard -- none deterministic headless, so
-- we swap them for synchronous stand-ins for the whole suite.
local orig = {}
local trapper_go  -- controls Trapper:info's return (download-cancel tests)
local function set_trapper_go(fn) trapper_go = fn end

local function install_stubs()
  orig.loadWithTrapper = UiUtil.loadWithTrapper
  orig.wrap, orig.info, orig.clear = Trapper.wrap, Trapper.info, Trapper.clear
  orig.isk_id, orig.isk_mid = InputDialog.onShowKeyboard, MultiInputDialog.onShowKeyboard

  UiUtil.loadWithTrapper = function(_label, fetch, onOk)
    local res = fetch()
    if res then onOk(res) end
  end
  Trapper.wrap  = function(_self, fn) return fn() end
  Trapper.info  = function(_self, text) return trapper_go == nil or trapper_go(text) end
  Trapper.clear = function() end
  InputDialog.onShowKeyboard = function() end
  MultiInputDialog.onShowKeyboard = function() end
end

local function restore_stubs()
  UiUtil.loadWithTrapper = orig.loadWithTrapper
  Trapper.wrap, Trapper.info, Trapper.clear = orig.wrap, orig.info, orig.clear
  InputDialog.onShowKeyboard, MultiInputDialog.onShowKeyboard = orig.isk_id, orig.isk_mid
end

describe("Komga plugin — UI integration (real KOReader frontend)", function()
  local orig_show, orig_close

  setup(function()
    orig_show, orig_close = UIManager.show, UIManager.close
    install_stubs()
  end)

  teardown(function()
    UIManager.show, UIManager.close = orig_show, orig_close
    restore_stubs()
  end)

  before_each(function()
    shown, closed = {}, {}
    trapper_go = nil
    UIManager.show  = function(_self, widget) shown[#shown + 1] = widget end
    UIManager.close = function(_self, widget) closed[#closed + 1] = widget end
  end)

  it("loads every runtime-dependent module without error", function()
    assert.has_no.errors(function()
      require("views/home_browser")
      require("views/series_browser")
      require("views/collections_browser")
      require("views/chapter_picker")
      require("domain/downloader")
      require("common/settings")
      require("views/ui_util")
      require("main")
    end)
  end)

  describe("chapter_picker", function()
    local ChapterPicker = require("views/chapter_picker")

    it("renders preloaded chapters with the right row text and status glyphs", function()
      ChapterPicker.show({ title = "One Piece", books = sample_books() }, function() end)
      local menu = last_menu()
      assert.is_truthy(menu)
      assert.equals(3, #menu.item_table)
      assert.equals("▢ One Piece #1", menu.item_table[1].text)
      assert.equals("▢ One Piece #2 ✔", menu.item_table[2].text)
      assert.equals("▢ One Piece #3 …", menu.item_table[3].text)
    end)

    it("toggles a chapter's checkbox when tapped", function()
      ChapterPicker.show({ title = "One Piece", books = sample_books() }, function() end)
      local menu = last_menu()
      menu.onMenuSelect(menu, menu.item_table[1])
      assert.equals("✓ One Piece #1", menu.item_table[1].text)
      menu.onMenuSelect(menu, menu.item_table[1])
      assert.equals("▢ One Piece #1", menu.item_table[1].text)
    end)

    it("downloads the chapters chosen via the actions popup (end-to-end)", function()
      local got
      ChapterPicker.show({ title = "One Piece", books = sample_books() },
        function(chosen) got = chosen end)
      local menu = last_menu()
      menu.onLeftButtonTap()
      local dialog = last_dialog()
      assert.is_truthy(dialog)
      assert.is_true(tap_button(dialog, "Select unread"))
      assert.is_true(tap_button(dialog, "Download"))
      assert.is_truthy(got)
      assert.equals(2, #got)
    end)
  end)

  describe("home_browser", function()
    local HomeBrowser = require("views/home_browser")
    local function ctx() return { download_dir = nil, on_download = function() end } end

    it("builds the six browse modes in order", function()
      HomeBrowser.show(fake_api(), ctx())
      local menu = last_menu()
      assert.is_truthy(menu)
      assert.equals(6, #menu.item_table)
      assert.equals("Reading", menu.item_table[1].text)
      assert.equals("Deck", menu.item_table[2].text)
      assert.equals("Last Updated", menu.item_table[3].text)
      assert.equals("Last Added Series", menu.item_table[4].text)
      assert.equals("Collections", menu.item_table[5].text)
      assert.equals("All", menu.item_table[6].text)  -- pgettext("Search text","All") -> "All" under C
    end)

    it("opens a chapter list for a chapter-mode (Reading)", function()
      local hits = 0
      HomeBrowser.show(fake_api({ booksInProgress = function() hits = hits + 1; return { items = sample_books() } end }), ctx())
      local home = last_menu()
      home.onMenuSelect(home, home.item_table[1])
      assert.equals(1, hits)
      local picker = last_menu()
      assert.equals(3, #picker.item_table)
      assert.equals("▢ One Piece #1", picker.item_table[1].text)
    end)

    it("opens a series list for a series-mode (Last Added Series)", function()
      local hits = 0
      HomeBrowser.show(fake_api({ seriesNew = function() hits = hits + 1; return { items = sample_series() } end }), ctx())
      local home = last_menu()
      home.onMenuSelect(home, home.item_table[4])
      assert.equals(1, hits)
      local series = last_menu()
      assert.equals("↻ Refresh", series.item_table[1].text)
      assert.equals("One Piece  (3/10)", series.item_table[2].text)
    end)

    it("opens the collections browser for the Collections mode", function()
      local hits = 0
      HomeBrowser.show(fake_api({ listCollections = function() hits = hits + 1; return { items = sample_collections() } end }), ctx())
      local home = last_menu()
      home.onMenuSelect(home, home.item_table[5])
      assert.equals(1, hits)
      local cols = last_menu()
      assert.equals("Shonen  (5)", cols.item_table[2].text)
    end)
  end)

  describe("series_browser", function()
    local SeriesBrowser = require("views/series_browser")

    it("renders series rows with unread/total and a Refresh row", function()
      SeriesBrowser.show({ title = "Komga", fetch = function() return { items = sample_series() } end }, function() end)
      local menu = last_menu()
      assert.equals("↻ Refresh", menu.item_table[1].text)
      assert.equals("One Piece  (3/10)", menu.item_table[2].text)
      assert.equals("Naruto  (0/72)", menu.item_table[3].text)
    end)

    it("shows a search row when search is enabled and runs the query", function()
      local searched
      SeriesBrowser.show({
        title = "Komga",
        fetch = function() return { items = sample_series() } end,
        search = function(q) searched = q; return { items = { sample_series()[2] } } end,
      }, function() end)
      local menu = last_menu()
      assert.equals("Search", menu.item_table[1].text)
      menu.onMenuSelect(menu, menu.item_table[1])
      local dlg = last_dialog()
      assert.is_truthy(dlg)
      dlg.getInputText = function() return "naru" end
      assert.is_true(tap_button(dlg, "Search"))
      assert.equals("naru", searched)
      assert.equals("Naruto  (0/72)", last_menu().item_table[3].text)
    end)

    it("shows 'No items' when the list is empty", function()
      SeriesBrowser.show({ title = "Komga", fetch = function() return { items = {} } end }, function() end)
      local menu = last_menu()
      assert.equals("No items", menu.item_table[#menu.item_table].text)
    end)

    it("invokes on_pick when a series row is tapped", function()
      local picked
      SeriesBrowser.show({ title = "Komga", fetch = function() return { items = sample_series() } end },
        function(s) picked = s end)
      local menu = last_menu()
      menu.onMenuSelect(menu, menu.item_table[2])
      assert.is_truthy(picked)
      assert.equals("s1", picked.id)
    end)
  end)

  describe("collections_browser", function()
    local CollectionsBrowser = require("views/collections_browser")
    local function ctx() return { download_dir = nil, on_download = function() end } end

    it("lists collections with a count and a Refresh row", function()
      CollectionsBrowser.show(fake_api(), ctx())
      local menu = last_menu()
      assert.equals("↻ Refresh", menu.item_table[1].text)
      assert.equals("Shonen  (5)", menu.item_table[2].text)
    end)

    it("shows 'No items' when there are no collections", function()
      CollectionsBrowser.show(fake_api({ listCollections = function() return { items = {} } end }), ctx())
      local menu = last_menu()
      assert.equals("No items", menu.item_table[#menu.item_table].text)
    end)

    it("opens a scoped series list when a collection is tapped", function()
      local scoped
      CollectionsBrowser.show(
        fake_api({ collectionSeries = function(_self, id) scoped = id; return { items = sample_series() } end }),
        ctx())
      local cols = last_menu()
      cols.onMenuSelect(cols, cols.item_table[2])
      assert.equals("c1", scoped)
      local series = last_menu()
      assert.equals("One Piece  (3/10)", series.item_table[2].text)
    end)
  end)

  describe("chapter_picker — actions", function()
    local ChapterPicker = require("views/chapter_picker")
    local DownloadPath = require("domain/download_path")

    local function open_actions(opts, on_download)
      ChapterPicker.show(opts, on_download or function() end)
      local menu = last_menu()
      menu.onLeftButtonTap()
      return menu, last_dialog()
    end

    it("exposes the title-bar menu icon and left-tap handler", function()
      ChapterPicker.show({ title = "One Piece", books = sample_books() }, function() end)
      local menu = last_menu()
      assert.equals("appbar.menu", menu.title_bar_left_icon)
      assert.is_function(menu.onLeftButtonTap)
    end)

    it("hides 'Next N unread…' for mixed lists and shows it for single-series", function()
      local _, mixed = open_actions({ title = "Mixed", books = sample_books(), mixed = true })
      assert.is_false(tap_button(mixed, "Next N unread"))
      local _, single = open_actions({ title = "One Piece", books = sample_books(), mixed = false })
      assert.is_true(tap_button(single, "Next N unread"))
    end)

    it("selects the next N unread after the last-read chapter", function()
      local _, dlg = open_actions({ title = "One Piece", books = sample_books(), mixed = false })
      assert.is_true(tap_button(dlg, "Next N unread"))
      local prompt = last_dialog()
      prompt.getInputText = function() return "1" end
      assert.is_true(tap_button(prompt, "OK"))
      -- last completed is b2 (sort 2); next unread after it is b3, not b1
      local menu = last_menu()
      assert.equals("✓ One Piece #3 …", menu.item_table[3].text)
      assert.equals("▢ One Piece #1", menu.item_table[1].text)
    end)

    it("Select all then Clear toggles every checkbox", function()
      local menu, dlg = open_actions({ title = "One Piece", books = sample_books() })
      assert.is_true(tap_button(dlg, "Select all"))
      for i = 1, 3 do assert.is_truthy(menu.item_table[i].text:find("✓", 1, true)) end
      menu.onLeftButtonTap()
      assert.is_true(tap_button(last_dialog(), "Clear"))
      for i = 1, 3 do assert.is_truthy(menu.item_table[i].text:find("▢", 1, true)) end
    end)

    it("shows the live selected count on the Download button", function()
      local menu, dlg = open_actions({ title = "One Piece", books = sample_books() })
      assert.is_true(tap_button(dlg, "Select all"))
      menu.onLeftButtonTap()
      local reopened = last_dialog()
      local found
      for _, row in ipairs(reopened.buttons) do
        for _, b in ipairs(row) do if b.text:find("Download", 1, true) then found = b.text end end
      end
      assert.equals("⬇ Download (3)", found)
    end)

    it("warns when Download is tapped with nothing selected", function()
      local _, dlg = open_actions({ title = "One Piece", books = sample_books() })
      assert.is_true(tap_button(dlg, "Download"))
      assert.equals("Nothing selected.", last_info().text)
    end)

    it("Refresh re-fetches via the fetch function", function()
      local hits = 0
      local _, dlg = open_actions({ title = "One Piece", mixed = false,
        fetch = function() hits = hits + 1; return { items = sample_books() } end })
      assert.equals(1, hits)
      assert.is_true(tap_button(dlg, "Refresh"))
      assert.equals(2, hits)
    end)

    it("marks chapters already present on disk with the ⤓ glyph", function()
      local dir = tmpdir()
      local path = DownloadPath.forBook(dir, "One Piece", 1)
      util.makePath(path:match("(.*)/[^/]+$"))
      local f = io.open(path, "w"); f:write("x"); f:close()
      ChapterPicker.show({ title = "One Piece", books = sample_books(), download_dir = dir }, function() end)
      local menu = last_menu()
      assert.equals("▢ One Piece #1 ⤓", menu.item_table[1].text)
      assert.equals("▢ One Piece #2 ✔", menu.item_table[2].text)
      os.remove(path)
    end)
  end)

  describe("downloader", function()
    local Downloader = require("domain/downloader")

    -- downloadBook that writes the file, so a re-run sees it as already existing.
    local function writer()
      return function(_self, _id, dest)
        local f = io.open(dest, "w"); if not f then return false end
        f:write("cbz"); f:close(); return true
      end
    end

    it("downloads all chapters and reports the summary counts", function()
      local dir = tmpdir()
      Downloader.run(fake_api({ downloadBook = writer() }), dir, sample_books())
      local msg = last_info().text
      assert.is_truthy(msg:find("Done", 1, true))
      assert.is_truthy(msg:find("Downloaded: 3", 1, true))
      assert.is_truthy(msg:find("Skipped (exists): 0", 1, true))
      assert.is_truthy(msg:find("Failed: 0", 1, true))
    end)

    it("skips chapters whose file already exists", function()
      local dir = tmpdir()
      Downloader.run(fake_api({ downloadBook = writer() }), dir, sample_books())
      Downloader.run(fake_api({ downloadBook = writer() }), dir, sample_books())
      local msg = last_info().text
      assert.is_truthy(msg:find("Downloaded: 0", 1, true))
      assert.is_truthy(msg:find("Skipped (exists): 3", 1, true))
    end)

    it("counts a failed download", function()
      local dir = tmpdir()
      Downloader.run(fake_api({ downloadBook = function() return false end }), dir, sample_books())
      local msg = last_info().text
      assert.is_truthy(msg:find("Failed: 3", 1, true))
    end)

    it("stops between chapters when the progress popup is dismissed", function()
      local dir = tmpdir()
      local calls = 0
      set_trapper_go(function() calls = calls + 1; return calls <= 1 end)  -- allow 1, then cancel
      Downloader.run(fake_api({ downloadBook = writer() }), dir, sample_books())
      local msg = last_info().text
      assert.is_truthy(msg:find("Stopped.", 1, true))
      assert.is_truthy(msg:find("Downloaded: 1", 1, true))
    end)
  end)

  describe("settings (main.lua)", function()
    local Komga = require("main")

    it("guards Browse when not configured", function()
      local opened = false
      local self_ = { settings = fake_settings(nil), showConfig = function() opened = true end }
      Komga.onBrowse(self_)
      assert.equals("Set the server URL and API key first.", last_info().text)
      local info = last_info()
      if info.dismiss_callback then info.dismiss_callback() end
      assert.is_true(opened)
    end)

    it("saves and normalizes the URL + API key", function()
      local settings = fake_settings(nil)
      local self_ = { settings = settings }
      Komga.showConfig(self_)
      local dlg = last_dialog()
      assert.is_truthy(dlg)
      dlg.getFields = function() return { "https://komga.example.com/ ", "  KEY123  " } end
      assert.is_true(tap_button(dlg, "Save"))
      assert.equals("https://komga.example.com", settings._store.base_url)
      assert.equals("KEY123", settings._store.api_key)
      assert.equals("Saved", last_info().text)
    end)
  end)
end)
