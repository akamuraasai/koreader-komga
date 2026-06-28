-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local DownloadResult = {}

function DownloadResult.new() return { ok = 0, skip = 0, fail = 0, stopped = false } end
function DownloadResult.ok(r)   r.ok = r.ok + 1 end
function DownloadResult.skip(r) r.skip = r.skip + 1 end
function DownloadResult.fail(r) r.fail = r.fail + 1 end
function DownloadResult.stop(r) r.stopped = true end

return DownloadResult
