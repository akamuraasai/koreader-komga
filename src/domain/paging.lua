-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local Paging = {}

-- 1-based index of the first item on the current page, used to keep a Menu on the
-- same page across a switchItemTable rebuild. Returns nil when the page/perpage are
-- not known yet (first render), letting the Menu pick its default.
function Paging.firstVisibleIndex(page, perpage)
  if not (page and perpage) then return nil end
  return (page - 1) * perpage + 1
end

function Paging.hasMore(page, totalPages)
  return page < (totalPages or 1)
end

return Paging
