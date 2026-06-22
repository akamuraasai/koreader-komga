-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

-- ensure plugin modules are require-able by their layered path in tests
package.path = "./src/?.lua;" .. package.path
