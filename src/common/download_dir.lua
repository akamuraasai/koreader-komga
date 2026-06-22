-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local DownloadDir = {}

-- Resolve the download ROOT, in priority order: file-manager home > device home >
-- data dir, then append "/Komga". Pure (testable without the KOReader runtime).
-- A user-set custom dir is returned verbatim by the caller before reaching here.
function DownloadDir.resolve(homeSetting, deviceHome, dataDir)
  return (homeSetting or deviceHome or dataDir) .. "/Komga"
end

return DownloadDir
