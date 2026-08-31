-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

-- ensure plugin modules are require-able by their layered path in tests
package.path = "./src/?.lua;" .. package.path

-- stub gettext so views that translate strings load cleanly in unit tests
if not package.loaded["gettext"] then
  package.loaded["gettext"] = setmetatable({}, { __call = function(_, s) return s end })
end
