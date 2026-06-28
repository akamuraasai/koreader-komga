-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local ButtonDialog = require("ui/widget/buttondialog")
local lfs = require("libs/libkoreader-lfs")
local Selection = require("domain/selection")
local SelectionState = require("domain/selection_state")
local DownloadPlan = require("domain/download_plan")
local ChapterList = require("views/chapter_list")
local Paging = require("domain/paging")
local KomgaParse = require("api/komga_parse")
local UiUtil = require("views/ui_util")
local _ = require("gettext")
local T = require("ffi/util").template

local DEFAULT_NEXT_N = 20

local ChapterPicker = {}

-- opts = {
--   title        = string,
--   books        = { ... } | nil,   -- preloaded books, OR
--   fetch        = function() return { items = {...} } | nil, err end,
--   mixed        = boolean,          -- true: many series; hides the per-series "Next N"
--   download_dir = string | nil,     -- enables the "already downloaded" marker
-- }
function ChapterPicker.show(opts, on_download)
  local books = opts.books or {}
  local sel, downloaded, bases, menu = SelectionState.new(), {}, {}, nil
  local function has(id) return SelectionState.has(sel, id) end

  local function refreshDownloaded()
    downloaded = {}
    if opts.download_dir then
      for _, item in ipairs(DownloadPlan.resolve(books, opts.download_dir)) do
        if lfs.attributes(item.dest, "mode") == "file" then downloaded[item.book.id] = true end
      end
    end
    bases = ChapterList.precompute(books, downloaded)
  end

  local function rebuild()
    local first = Paging.firstVisibleIndex(menu.page, menu.perpage)
    -- Full repaint is inherent to KOReader's Menu; row base (buildItems) is cached per load, so per-tap cost is repaint, not string building.
    menu:switchItemTable(ChapterList.title(opts.title, sel.count),
      ChapterList.buildItems(books, bases, has), first)
  end

  local function selectIds(ids)
    for _, id in ipairs(ids) do SelectionState.set(sel, id, true) end
    rebuild()
  end

  local function reload()
    if not opts.fetch then return end
    UiUtil.loadWithTrapper(_("Loading chapters…"), opts.fetch, function(res)
      books = res.items
      local present = {}
      for _, b in ipairs(books) do present[b.id] = true end
      SelectionState.prune(sel, present)
      refreshDownloaded()
      rebuild()
    end)
  end

  local function startDownload()
    local chosen = Selection.chosen(books, has)
    if #chosen == 0 then
      UIManager:show(InfoMessage:new{ text = _("Nothing selected.") })
    else
      on_download(chosen, books)
    end
  end

  local function promptNextN()
    local i
    i = InputDialog:new{ title = _("How many?"), input = tostring(DEFAULT_NEXT_N), input_type = "number",
      buttons = {{ { text = _("OK"), is_enter_default = true, callback = function()
        local n = tonumber(i:getInputText()) or 0
        UIManager:close(i); selectIds(Selection.nextNUnread(books, n))
      end } }} }
    UIManager:show(i); i:onShowKeyboard()
  end

  -- Actions live behind the title-bar menu icon (a real button popup -- KOReader's Menu
  -- has no footer button row, and a composed bottom bar freezes the e-ink repaint loop).
  -- Rebuilt on each open so the Download count is current.
  local function actionsDialog()
    local dlg
    local function close() UIManager:close(dlg) end
    local spec = {
      { _("Select unread"), function() selectIds(Selection.unreadIds(books)) end },
      { _("Next N unread…"), promptNextN, not opts.mixed },
      { _("Select all"), function() selectIds(Selection.allIds(books)) end },
      { _("Clear"), function() SelectionState.clear(sel); rebuild() end },
      { "⬇ " .. T(_("Download (%1)"), sel.count), function() startDownload() end },
      { "↻ " .. _("Refresh"), function() reload() end },
    }
    local rows = {}
    for _, a in ipairs(spec) do
      if a[3] == nil or a[3] then
        rows[#rows + 1] = {{ text = a[1], callback = function() close(); a[2]() end }}
      end
    end
    dlg = ButtonDialog:new{ buttons = rows }
    UIManager:show(dlg)
  end

  menu = UiUtil.fullscreenMenu{
    title = opts.title,
    title_bar_left_icon = "appbar.menu",
    onLeftButtonTap = function() actionsDialog() end,
    onMenuSelect = function(_self, item)
      if item.book then
        SelectionState.set(sel, item.book.id, not has(item.book.id))
        rebuild()
      end
    end,
  }

  UIManager:show(menu)

  if opts.books then
    refreshDownloaded()
    rebuild()
  else
    reload()
  end
end

-- Convenience for the single-series leaf (All / Last Added Series / a Collection's series).
function ChapterPicker.showForSeries(api, series, ctx)
  ChapterPicker.show({
    title = series.title,
    mixed = false,
    download_dir = ctx.download_dir,
    fetch = function()
      local res, err = api:listBooks(series.id)
      if not res then return nil, err end
      res.items = KomgaParse.applySeriesTitle(res.items, series.title)
      return res
    end,
  }, ctx.on_download)
end

return ChapterPicker
