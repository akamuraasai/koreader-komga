-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local DownloadDir = {}

-- A non-empty custom dir wins verbatim; otherwise pick the first available public root
-- (file-manager home > device home > data dir) and append "/Komga". Pure.
function DownloadDir.resolve(custom, homeSetting, deviceHome, dataDir)
  if custom and custom ~= "" then return custom end
  return (homeSetting or deviceHome or dataDir) .. "/Komga"
end

return DownloadDir
