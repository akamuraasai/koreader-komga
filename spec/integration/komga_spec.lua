-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

-- Integration tests: exercise the plugin's UI modules inside the REAL KOReader
-- frontend (Menu, UIManager, ButtonDialog, ...), headlessly.
--
-- Run from a built koreader checkout with this file symlinked into spec/unit/ and
-- komga.koplugin symlinked into plugins/ (the repo's `make test-integration` does both):
--   cd <koreader> && ./kodev test front komga_spec.lua

describe("Komga plugin — UI integration (real KOReader frontend)", function()
  local ChapterPicker, UIManager
  local orig_show, orig_close
  local shown, closed

  setup(function()
    package.path = "plugins/komga.koplugin/?.lua;" .. package.path
    require("commonrequire")
    -- Force untranslated (English) labels so assertions don't depend on the system
    -- locale (the test env inherits it -- e.g. pt-BR would give "Baixar"/"Limpar").
    require("gettext").changeLang("C")
    UIManager = require("ui/uimanager")
    ChapterPicker = require("views/chapter_picker")
    orig_show, orig_close = UIManager.show, UIManager.close
  end)

  teardown(function()
    UIManager.show, UIManager.close = orig_show, orig_close
  end)

  before_each(function()
    -- Capture shown/closed widgets instead of rendering them.
    shown, closed = {}, {}
    UIManager.show = function(_, widget) shown[#shown + 1] = widget end
    UIManager.close = function(_, widget) closed[#closed + 1] = widget end
  end)

  local function sample_books()
    return {
      { id = "b1", seriesTitle = "One Piece", number = "1", sort = 1, completed = false, inProgress = false },
      { id = "b2", seriesTitle = "One Piece", number = "2", sort = 2, completed = true,  inProgress = false },
      { id = "b3", seriesTitle = "One Piece", number = "3", sort = 3, completed = false, inProgress = true },
    }
  end

  -- The chapter list menu is the shown widget carrying both an item_table and onMenuSelect.
  local function find_menu()
    for _, w in ipairs(shown) do
      if type(w) == "table" and w.item_table and w.onMenuSelect then return w end
    end
  end

  it("loads every runtime-dependent module without error", function()
    assert.has_no.errors(function()
      require("views/home_browser")
      require("views/series_browser")
      require("views/collections_browser")
      require("domain/downloader")
      require("common/settings")
      require("views/ui_util")
    end)
  end)

  it("renders preloaded chapters with the right row text and status glyphs", function()
    ChapterPicker.show({ title = "One Piece", books = sample_books() }, function() end)
    local menu = find_menu()
    assert.is_truthy(menu)
    assert.equals(3, #menu.item_table)
    assert.equals("▢ One Piece #1", menu.item_table[1].text)     -- unread
    assert.equals("▢ One Piece #2 ✔", menu.item_table[2].text)   -- completed
    assert.equals("▢ One Piece #3 …", menu.item_table[3].text)   -- in progress
  end)

  it("toggles a chapter's checkbox when tapped", function()
    ChapterPicker.show({ title = "One Piece", books = sample_books() }, function() end)
    local menu = find_menu()
    menu.onMenuSelect(menu, menu.item_table[1])
    assert.equals("✓ One Piece #1", menu.item_table[1].text)
    menu.onMenuSelect(menu, menu.item_table[1])  -- tap again -> deselect
    assert.equals("▢ One Piece #1", menu.item_table[1].text)
  end)

  it("downloads the chapters chosen via the actions popup (end-to-end)", function()
    local got
    ChapterPicker.show({ title = "One Piece", books = sample_books() },
      function(chosen) got = chosen end)
    local menu = find_menu()

    menu.onLeftButtonTap()                          -- open the actions popup
    local dialog = shown[#shown]
    assert.is_truthy(dialog and dialog.buttons)     -- popup opened

    -- Tap a button on the open popup. close() is a no-op stub here, so the dialog's
    -- callbacks stay valid across taps.
    local function tap(label)
      for _, row in ipairs(dialog.buttons) do
        for _, btn in ipairs(row) do
          if btn.text and btn.text:find(label, 1, true) then btn.callback(); return true end
        end
      end
      return false
    end

    assert.is_true(tap("Select unread"))   -- selects b1 + b3 (b2 is completed)
    assert.is_true(tap("Download"))        -- fires on_download with the selection
    assert.is_truthy(got)
    assert.equals(2, #got)
  end)
end)
