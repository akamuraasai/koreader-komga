-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local ButtonDialog = require("ui/widget/buttondialog")
local lfs = require("libs/libkoreader-lfs")
local Selection = require("domain/selection")
local DownloadPath = require("domain/download_path")
local ChapterRow = require("views/chapter_row")
local Paging = require("domain/paging")
local KomgaParse = require("api/komga_parse")
local UiUtil = require("views/ui_util")
local _ = require("gettext")

local DEFAULT_NEXT_N = 20  -- default count for the "Next N unread" prompt

local ChapterPicker = {}

-- opts = {
--   title        = string,
--   books        = { ... } | nil,   -- preloaded books, OR
--   fetch        = function() return { items = {...} } | nil, err end,
--   mixed        = boolean,          -- true: many series; hides the per-series "Next N"
--   download_dir = string | nil,     -- enables the "already downloaded" marker
-- }
function ChapterPicker.show(opts, on_download)
  local books, selected, downloaded, menu = opts.books or {}, {}, {}, nil
  local selected_count = 0

  -- Maintain the selected count incrementally so rebuild() (run on every tap) and the
  -- actions popup read it in O(1) instead of rescanning the whole selection each time.
  local function setSelected(id, on)
    on = on and true or nil
    if on == selected[id] then return end
    selected[id] = on
    selected_count = selected_count + (on and 1 or -1)
  end

  local function clearSelected()
    selected, selected_count = {}, 0
  end

  -- Compute on-disk presence ONCE per (re)load and cache it; never stat per keystroke
  -- (a filesystem stat per row on every toggle would be slow on e-ink).
  local function refreshDownloaded()
    downloaded = {}
    if not opts.download_dir then return end
    for _, b in ipairs(books) do
      local path = DownloadPath.forBook(opts.download_dir, b.seriesTitle, b.sort)
      if lfs.attributes(path, "mode") == "file" then downloaded[b.id] = true end
    end
  end

  local function rebuild()
    local items = {}
    if #books == 0 then
      items[#items + 1] = { text = _("No items") }
    end
    for _, b in ipairs(books) do
      items[#items + 1] = {
        text = ChapterRow.format(b, selected[b.id], downloaded[b.id]),
        book = b,
      }
    end
    -- Keep the menu on the current page across the rebuild.
    local first = Paging.firstVisibleIndex(menu.page, menu.perpage)
    menu:switchItemTable(opts.title .. "  [" .. selected_count .. "]", items, first)
  end

  local function selectIds(ids)
    for _, id in ipairs(ids) do setSelected(id, true) end
    rebuild()
  end

  local function reload()
    if not opts.fetch then return end
    UiUtil.loadWithTrapper(_("Loading chapters…"), opts.fetch, function(res)
      books = res.items
      refreshDownloaded()
      rebuild()
    end)
  end

  local function startDownload()
    local chosen = {}
    for _, b in ipairs(books) do if selected[b.id] then chosen[#chosen + 1] = b end end
    if #chosen == 0 then
      UIManager:show(InfoMessage:new{ text = _("Nothing selected.") })
    else
      on_download(chosen)
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

  -- Actions live behind the title-bar menu icon (always visible on every page, and
  -- a real button popup — KOReader's Menu has no native footer button row, and a
  -- composed full-screen bottom bar freezes the repaint loop on e-ink). The popup is
  -- rebuilt on each open so the Download count is current.
  local function actionsDialog()
    local dlg
    local function close() UIManager:close(dlg) end
    local rows = {
      {{ text = _("Select unread"), callback = function() close(); selectIds(Selection.unreadIds(books)) end }},
    }
    if not opts.mixed then
      rows[#rows + 1] = {{ text = _("Next N unread…"), callback = function() close(); promptNextN() end }}
    end
    rows[#rows + 1] = {{ text = _("Select all"), callback = function()
        close(); for _, b in ipairs(books) do setSelected(b.id, true) end; rebuild() end }}
    rows[#rows + 1] = {{ text = _("Clear"), callback = function() close(); clearSelected(); rebuild() end }}
    rows[#rows + 1] = {{ text = "⬇ " .. _("Download") .. " (" .. selected_count .. ")",
        callback = function() close(); startDownload() end }}
    rows[#rows + 1] = {{ text = "↻ " .. _("Refresh"), callback = function() close(); reload() end }}
    dlg = ButtonDialog:new{ buttons = rows }
    UIManager:show(dlg)
  end

  -- The Menu exposes only the LEFT title-bar icon for custom use (the right is always
  -- its close button); "appbar.menu" is a valid icon in KOReader's set. Actions live
  -- behind it as a real button popup -- see actionsDialog.
  menu = UiUtil.fullscreenMenu{
    title = opts.title,
    title_bar_left_icon = "appbar.menu",
    onLeftButtonTap = function() actionsDialog() end,
    onMenuSelect = function(_self, item)
      if item.book then
        setSelected(item.book.id, not selected[item.book.id])
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
